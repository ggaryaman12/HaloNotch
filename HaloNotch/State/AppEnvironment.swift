import SwiftUI
import Observation

/// Dependency-injection container shared across the SwiftUI tree and AppKit layer.
/// Holds preferences plus every feature service. Created once in `AppDelegate`.
@Observable
final class AppEnvironment {
    let preferences = Preferences()
    let media: any MediaController
    let visualizer = VisualizerEngine()
    let battery = BatteryMonitor()
    let shelf = ShelfModel()
    let calendar = CalendarService()
    let hud = HUDManager()
    let extensions = ExtensionRegistry()
    let lyrics = LyricsService()
    let claude = ClaudeMonitor()

    /// The notch UI state machine. Lives here so AppKit and SwiftUI share one instance.
    let notch = NotchViewModel()

    init() {
        // Real Now Playing via the bundled mediaremote-adapter (perl host); falls back
        // to a demo track internally if the adapter can't be located/launched.
        media = AdapterMediaController()
    }

    /// Wires services together and begins observing the system. Called after launch.
    func start() {
        battery.start()
        hud.start(enabled: preferences.hudEnabled)
        media.start(demoFallback: preferences.demoMediaFallback)
        // Drive the visualizer from playback state.
        visualizer.bind(isPlaying: { [weak self] in self?.media.isPlaying ?? false })
        extensions.registerBuiltins()

        // Pop the notch out to the Claude tab whenever Claude needs attention.
        claude.onAttention = { [weak self] in
            DispatchQueue.main.async { self?.notch.present(.claude) }
        }
        claude.start()

        // Briefly pop the media glance whenever a new track starts.
        observeTrackChanges()
    }

    private var lastPoppedTrack: String?

    /// Observe the now-playing title and pop a short media glance on each new track
    /// (including the first). Re-registers itself after every change.
    private func observeTrackChanges() {
        withObservationTracking {
            _ = media.nowPlaying?.title
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.handleTrackChange()
                self?.observeTrackChanges()
            }
        }
    }

    private func handleTrackChange() {
        guard preferences.mediaEnabled,
              let title = media.nowPlaying?.title, !title.isEmpty,
              title != lastPoppedTrack else { return }
        lastPoppedTrack = title
        // Don't steal the notch while Claude is waiting on the user.
        guard claude.status != .waiting else { return }

        notch.present(.media)
        notch.pinnedUntil = Date().addingTimeInterval(3.5)
        let token = title
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) { [weak self] in
            guard let self, self.lastPoppedTrack == token else { return }   // newer track took over
            if self.notch.state == .open && self.notch.selectedTab == .media {
                self.notch.send(.dismissed)
            }
        }
    }
}
