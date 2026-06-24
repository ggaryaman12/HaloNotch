import SwiftUI

/// App entry point. The visible UI lives in a borderless `NotchWindow` managed by
/// `AppDelegate`; the SwiftUI `Settings` scene provides the standard ⌘, window.
@main
struct HaloNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.env)
        }
    }
}
