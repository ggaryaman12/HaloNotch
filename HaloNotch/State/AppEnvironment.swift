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
    }
}
