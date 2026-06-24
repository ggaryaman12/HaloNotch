import AppKit
import SwiftUI
import CoreGraphics

/// Owns the app lifecycle: accessory activation policy (no Dock icon), the menu-bar
/// status item, the global `AppEnvironment`, and the borderless notch panel.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let env = AppEnvironment()

    private var statusItem: NSStatusItem?
    private var notchWindow: NotchWindow?
    private var onboardingWindow: NSWindow?
    private var ambientWindow: NSWindow?
    private var ambientEscMonitor: Any?
    private var idleTimer: Timer?
    private var ambientAutoShown = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Agent app: live in the menu bar, not the Dock.
        NSApp.setActivationPolicy(.accessory)

        env.start()
        installStatusItem()
        installNotchWindow()

        if !env.preferences.hasCompletedOnboarding {
            showOnboarding()
        }

        if ProcessInfo.processInfo.environment["HALO_AMBIENT"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.toggleAmbient() }
        }

        startIdleMonitor()
    }

    /// Auto-shows the ambient screen after ~2 min of no input (a screensaver-style
    /// stand-in for a "lock screen", since apps can't draw on the real one), and
    /// dismisses it on activity. Gated by the `ambientOnIdle` preference.
    private func startIdleMonitor() {
        let threshold: CFTimeInterval = 120
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, self.env.preferences.ambientOnIdle else { return }
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
            if idle >= threshold, self.ambientWindow == nil {
                self.ambientAutoShown = true
                self.toggleAmbient()
            } else if idle < 2, self.ambientAutoShown, let w = self.ambientWindow {
                self.ambientAutoShown = false
                self.closeAmbient(w)
            }
        }
    }

    // MARK: Notch panel

    private func installNotchWindow() {
        let window = NotchWindow(env: env)
        window.placeUnderNotch()
        window.orderFrontRegardless()
        notchWindow = window
    }

    // MARK: Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                     accessibilityDescription: "HaloNotch")
        let menu = NSMenu()
        menu.addItem(withTitle: "HaloNotch", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Ambient Screen", action: #selector(toggleAmbient), keyEquivalent: "a")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Replay Onboarding", action: #selector(showOnboarding), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit HaloNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for menuItem in menu.items where menuItem.action != nil { menuItem.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleAmbient() {
        if let w = ambientWindow {
            closeAmbient(w); return
        }
        guard let screen = NSScreen.main else { return }
        let window = NSWindow(contentRect: screen.frame,
                              styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.setFrame(screen.frame, display: true)
        window.contentView = NSHostingView(
            rootView: AmbientView(onClose: { [weak self] in
                if let w = self?.ambientWindow { self?.closeAmbient(w) }
            }).environment(env))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        ambientWindow = window
        if ProcessInfo.processInfo.environment["HALO_DEBUG"] != nil {
            FileHandle.standardError.write("ambient screen.frame=\(screen.frame) window.frame=\(window.frame) contentView=\(String(describing: window.contentView?.frame))\n".data(using: .utf8)!)
        }

        ambientEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                if let w = self?.ambientWindow { self?.closeAmbient(w) }
                return nil
            }
            return event
        }
    }

    private func closeAmbient(_ window: NSWindow) {
        window.orderOut(nil)
        ambientWindow = nil
        if let m = ambientEscMonitor { NSEvent.removeMonitor(m); ambientEscMonitor = nil }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func showOnboarding() {
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.contentView = NSHostingView(
            rootView: OnboardingView(onFinish: { [weak self] in
                self?.env.preferences.hasCompletedOnboarding = true
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            })
            .environment(env)
        )
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
