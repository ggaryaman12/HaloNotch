import AppKit
import SwiftUI
import Observation

/// Borderless, non-activating panel pinned under the physical notch.
///
/// Design note: the window is a FIXED size (large enough for the open card) and is
/// never resized. The SwiftUI content draws the notch top-center and grows downward
/// within it. This avoids the `NSHostingView` ↔ window constraint-cycle abort that
/// happens when a borderless panel is resized while hosting SwiftUI. Mouse events
/// pass through (window is click-through) until the notch is opened, so the menu bar
/// and desktop behind it stay usable.
final class NotchWindow: NSPanel {
    private let env: AppEnvironment
    private var metrics: NotchMetrics
    private var closeWorkItem: DispatchWorkItem?
    private var monitors: [Any] = []

    init(env: AppEnvironment) {
        self.env = env
        self.metrics = ScreenManager.currentMetrics()
        env.notch.closedSize = metrics.closedRect.size

        // Fixed window: wide enough for the open card, tall enough to grow downward.
        let winSize = CGSize(width: max(500, metrics.closedRect.width + 300), height: 320)
        let origin = CGPoint(x: metrics.centerX - winSize.width / 2,
                             y: metrics.topY - winSize.height)

        super.init(contentRect: CGRect(origin: origin, size: winSize),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)

        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true   // click-through until opened
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let hosting = FirstMouseHostingView(rootView: NotchRootView().environment(env))
        hosting.sizingOptions = []  // we own the frame; don't let it resize the window
        hosting.frame = CGRect(origin: .zero, size: winSize)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        observeInteractivity()
        installMouseMonitors()
    }

    deinit { monitors.forEach { NSEvent.removeMonitor($0) } }

    // Never become key: clicks are hit-tested via the global mouse monitors, so the
    // panel never needs first-responder. Staying non-key means clicking the notch does
    // NOT blur the focused field in the active app (e.g. the VS Code Claude input), so
    // synthesized answer keystrokes still land there.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: Placement

    func placeUnderNotch() {
        metrics = ScreenManager.currentMetrics()
        env.notch.closedSize = metrics.closedRect.size
        let s = frame.size
        setFrameOrigin(CGPoint(x: metrics.centerX - s.width / 2, y: metrics.topY - s.height))
    }

    /// The screen-space rect of the notch card for the current state (top-center).
    private func notchRect(for state: NotchState) -> CGRect {
        let size = env.notch.size(for: state)
        return CGRect(x: metrics.centerX - size.width / 2,
                      y: metrics.topY - size.height,
                      width: size.width, height: size.height)
    }

    // MARK: Mouse handling (global monitors — reliable on a click-through panel)

    private func installMouseMonitors() {
        let moved: (NSEvent) -> Void = { [weak self] _ in self?.evaluateCursor() }
        let down: (NSEvent) -> Void = { [weak self] _ in self?.handleClick() }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: moved) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { moved($0); return $0 }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown], handler: down) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown], handler: { down($0); return $0 }) { monitors.append(m) }
    }

    private func evaluateCursor() {
        let loc = NSEvent.mouseLocation
        let inside = notchRect(for: env.notch.state).insetBy(dx: -4, dy: -4).contains(loc)
        switch env.notch.state {
        case .closed:
            if inside { closeWorkItem?.cancel(); env.notch.send(.mouseEntered) }
        case .hovered:
            if inside { closeWorkItem?.cancel(); updateParallax(loc) } else { env.notch.send(.mouseExited) }
        case .open:
            if inside { closeWorkItem?.cancel(); updateParallax(loc) }
            else if Date() > env.notch.pinnedUntil { scheduleClose() }
        }
    }

    /// Drive the card's perspective tilt from the cursor position within the notch, so
    /// the open/hover card has a live 3D lean toward the pointer.
    private func updateParallax(_ loc: CGPoint) {
        let r = notchRect(for: env.notch.state)
        guard r.width > 1, r.height > 1 else { return }
        let nx = max(-1, min(1, (loc.x - r.midX) / (r.width / 2)))
        let ny = max(-1, min(1, (loc.y - r.midY) / (r.height / 2)))
        // Magnitude tuned so the lift modifier yields a few degrees of tilt. Screen Y is
        // up, so invert it to lean the top of the card toward the cursor.
        env.notch.parallax = CGSize(width: nx * 40, height: -ny * 40)
    }

    private func handleClick() {
        let loc = NSEvent.mouseLocation
        let state = env.notch.state
        // Screen click → window-local, top-left space (matches the SwiftUI .global frames
        // published for hit-testing).
        let local = CGPoint(x: loc.x - frame.minX, y: frame.maxY - loc.y)

        if state == .open {
            // Hit-test the answer chips ourselves — fires even when the panel isn't key
            // (the SwiftUI Button path can't).
            if ProcessInfo.processInfo.environment["HALO_DEBUG"] != nil {
                FileHandle.standardError.write("click: screen=\(loc) winFrame=\(frame) local=\(local) rects=\(env.notch.answerRects)\n".data(using: .utf8)!)
            }
            if let hit = env.notch.answerRects.first(where: { $0.value.contains(local) }) {
                answerSelected(index: hit.key)
                return
            }
            if !notchRect(for: state).contains(loc) { env.notch.send(.dismissed) }
            return
        }

        if state == .hovered {
            // Transport controls in the hover strip — handle the tap without opening.
            if let hit = env.notch.mediaRects.first(where: { $0.value.contains(local) }) {
                switch hit.key {
                case .prev:      env.media.previous()
                case .playPause: env.media.playPause()
                case .next:      env.media.next()
                }
                return
            }
        }

        if notchRect(for: state).contains(loc) { env.notch.send(.clicked) }
    }

    private func answerSelected(index: Int) {
        guard let q = env.claude.pendingQuestion else { return }
        let opts = q.options.isEmpty ? ["Yes", "No"] : q.options
        _ = AnswerSender.sendChoice(index: index, options: opts, source: env.claude.source)
        env.notch.answerRects = [:]
        env.notch.send(.dismissed)
    }

    private func scheduleClose() {
        closeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.env.notch.send(.dismissed) }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    // MARK: Observation — toggle click-through with state (NO window resize)

    private func observeInteractivity() {
        withObservationTracking { _ = env.notch.state } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                // Only the open card needs to receive clicks/drops; otherwise pass through.
                self.ignoresMouseEvents = (self.env.notch.state != .open)
                self.observeInteractivity()
            }
        }
    }
}

/// Hosting view that acts on the very first click even when the panel isn't key.
/// Without this, the non-activating notch panel swallows the first click on a button
/// (AppKit uses it just to bring the window forward), so answer buttons feel dead while
/// another app (e.g. VS Code) is active.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
