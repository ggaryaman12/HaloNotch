import SwiftUI
import ServiceManagement

/// Preferences window (⌘,). Module toggles, 3D intensity, accent, launch-at-login,
/// and onboarding replay.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        @Bindable var prefs = env.preferences

        TabView {
            Form {
                Section("Modules") {
                    Toggle("Media & Visualizer", isOn: $prefs.mediaEnabled)
                    Toggle("Calendar", isOn: $prefs.calendarEnabled)
                    Toggle("File Shelf", isOn: $prefs.shelfEnabled)
                    Toggle("Battery Indicator", isOn: $prefs.batteryEnabled)
                    Toggle("HUD Replacement (volume)", isOn: $prefs.hudEnabled)
                    Toggle("Demo media when nothing is playing", isOn: $prefs.demoMediaFallback)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Modules", systemImage: "square.grid.2x2") }

            Form {
                Section("Motion") {
                    Picker("3D Intensity", selection: $prefs.threeDIntensity) {
                        ForEach(Preferences.ThreeDIntensity.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Appearance") {
                    LabeledContent("Accent") {
                        TextField("#RRGGBB", text: $prefs.accentHex).frame(width: 100)
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: prefs.accentHex))
                            .frame(width: 22, height: 16)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Appearance", systemImage: "paintbrush") }

            Form {
                Section("General") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                    Toggle("Show ambient screen when idle (~2 min)", isOn: $prefs.ambientOnIdle)
                    Button("Replay Onboarding") { prefs.hasCompletedOnboarding = false; replayOnboarding() }
                }
                Section("Extensions") {
                    ForEach(env.extensions.extensions) { ext in
                        Toggle(isOn: Binding(
                            get: { ext.enabled },
                            set: { env.extensions.setEnabled(ext.id, $0) })) {
                            Label(ext.title, systemImage: ext.symbol)
                        }
                    }
                }
                Section { Text("HaloNotch v0.1.0").foregroundStyle(.secondary) }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 460, height: 380)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private func replayOnboarding() {
        (NSApp.delegate as? AppDelegate)?.perform(Selector(("showOnboarding")))
    }
}
