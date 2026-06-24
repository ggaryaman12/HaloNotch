import SwiftUI
import Observation

/// A pluggable notch panel. New behaviors register a `NotchExtension` with the
/// registry; the UI can surface them without the core knowing their internals.
struct NotchExtension: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var enabled: Bool = true
    let makeView: () -> AnyView
}

/// Holds available extensions. Built-ins are registered at launch; third parties
/// would call `register(_:)`.
@Observable
final class ExtensionRegistry {
    private(set) var extensions: [NotchExtension] = []

    func register(_ ext: NotchExtension) {
        guard !extensions.contains(where: { $0.id == ext.id }) else { return }
        extensions.append(ext)
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        guard let i = extensions.firstIndex(where: { $0.id == id }) else { return }
        extensions[i].enabled = enabled
    }

    func registerBuiltins() {
        register(NotchExtension(id: "clock", title: "Clock", symbol: "clock") {
            AnyView(ClockExtensionView())
        })
    }
}

/// Example built-in extension: a live clock panel.
struct ClockExtensionView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            Text(ctx.date, format: .dateTime.hour().minute().second())
                .font(.system(.title2, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
