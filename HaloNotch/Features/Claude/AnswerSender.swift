import AppKit
import CoreGraphics
import ApplicationServices

/// Sends an answer to the Claude Code session that asked. There is no API to inject
/// text into a specific session, so we do the next best thing: bring the owning app
/// (the terminal, or the editor running the VS Code extension) to the front, then
/// synthesize the keystrokes — which land in that app's focused input (the Claude
/// prompt, when it's waiting). Requires Accessibility permission.
enum AnswerSender {
    private static let terminalBundles: [String] = [
        "dev.warp.Warp-Stable", "dev.warp.Warp", "com.googlecode.iterm2",
        "com.apple.Terminal", "net.kovidgoyal.kitty", "io.alacritty",
        "co.zeit.hyper", "com.github.wez.wezterm",
    ]
    private static let editorBundles: [String] = [
        "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92",   // Cursor
        "com.visualstudio.code.oss", "com.vscodium",
    ]

    /// Route an answer to the session's owning app. Returns true if delivered via keys.
    @discardableResult
    static func send(_ text: String, source: ClaudeMonitor.Source) -> Bool {
        let bundles = (source == .editor) ? editorBundles : terminalBundles
        guard let app = activate(bundles) else {
            // App not running — copy so the user can paste.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return false
        }
        // Give focus a moment to settle on the activated app, then type.
        let delay = app.isActive ? 0.05 : 0.22
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            type(text)
            // Let the picker register the typed selection before committing it.
            // Sending Return in the same tick lands before the UI updates → no submit.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { pressReturn() }
        }
        return true
    }

    /// Pick an option in an AskUserQuestion prompt. Both the CLI and the VS Code
    /// extension render these as an arrow-driven picker (the highlighted row starts at
    /// index 0), so typing a number does nothing — we move Down to the target row, then
    /// press Return to commit. Returns true if delivered via keys.
    @discardableResult
    static func sendChoice(index: Int, options: [String], source: ClaudeMonitor.Source) -> Bool {
        let bundles = (source == .editor) ? editorBundles : terminalBundles
        guard let app = activate(bundles) else {
            // App not running — copy the label so the user can paste/answer manually.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(options.indices.contains(index) ? options[index] : "", forType: .string)
            return false
        }
        if ProcessInfo.processInfo.environment["HALO_DEBUG"] != nil {
            FileHandle.standardError.write("sendChoice idx=\(index) src=\(source) app=\(app.localizedName ?? "?") active=\(app.isActive) AXTrusted=\(AXIsProcessTrusted())\n".data(using: .utf8)!)
        }
        let delay = app.isActive ? 0.08 : 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Both the CLI and the VS Code Claude pickers are arrow-driven and start with
            // the first row highlighted: move Down to the target row, then Return. (Typing
            // the option number does NOT move the selection in the VS Code picker.)
            navigate(downBy: max(0, index)) {
                // Commit with Return. The VS Code picker can need two Enters (one to lock
                // the selection, one to submit); arrowing usually collapses that to one,
                // but a spaced second Return is harmless once it's already submitted.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    pressReturn()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { pressReturn() }
                }
            }
        }
        return true
    }

    /// Press the Down arrow `n` times with a gap between presses (so the picker keeps
    /// up), then run `completion`.
    private static func navigate(downBy n: Int, then completion: @escaping () -> Void) {
        guard n > 0 else { completion(); return }
        pressKey(0x7D)   // Down arrow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            navigate(downBy: n - 1, then: completion)
        }
    }

    /// Activate the first running app from the list. Returns it (or nil if none run).
    private static func activate(_ bundles: [String]) -> NSRunningApplication? {
        // Prefer the one already frontmost (avoids an unnecessary app switch).
        if let front = NSWorkspace.shared.frontmostApplication,
           let id = front.bundleIdentifier, bundles.contains(id) {
            return front
        }
        for id in bundles {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
                app.activate(options: [.activateAllWindows])
                return app
            }
        }
        return nil
    }

    private static func type(_ s: String) {
        let src = CGEventSource(stateID: .combinedSessionState)
        for ch in s {
            for half in [true, false] {
                guard let e = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: half) else { continue }
                var units = Array(String(ch).utf16)
                e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
                e.post(tap: .cghidEventTap)
            }
        }
    }

    private static func pressReturn() { pressKey(0x24) }

    private static func pressKey(_ vk: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: vk, keyDown: false)?.post(tap: .cghidEventTap)
    }
}
