import SwiftUI

/// Collects calendar "Join" button frames (window-local, top-left), keyed by event id,
/// so NotchWindow's global mouse monitor can open the meeting link on click (SwiftUI
/// Buttons can't receive clicks while the panel is intentionally non-key).
struct JoinRectKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Expanded calendar module: next events with countdowns and one-tap Join for any
/// event that has a Google Meet / Zoom / Teams link, or a permission prompt.
struct CalendarView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            switch env.calendar.access {
            case .granted:
                if env.calendar.upcoming.isEmpty {
                    empty("Nothing on the calendar")
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(env.calendar.upcoming) { event in
                            HStack(spacing: 6) {
                                Circle().fill(.white.opacity(0.5)).frame(width: 6, height: 6)
                                Text(event.title).font(Theme.Typography.body).lineLimit(1)
                                Spacer(minLength: 6)

                                if event.meetLink != nil {
                                    Text("Join")
                                        .font(Theme.Typography.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 9).padding(.vertical, 3)
                                        .background(Capsule().fill(Theme.Palette.good.opacity(0.9)))
                                        .background(GeometryReader { g in
                                            Color.clear.preference(key: JoinRectKey.self,
                                                                   value: [event.id: g.frame(in: .global)])
                                        })
                                }

                                Text(event.isAllDay ? "all day" : event.countdown)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .onPreferenceChange(JoinRectKey.self) { rects in
                        env.notch.joinRects = rects
                    }
                }
            case .denied:
                empty("Calendar access denied — enable in System Settings ▸ Privacy")
            case .unknown:
                VStack(spacing: 8) {
                    Image(systemName: "calendar").font(.title2)
                    Button("Connect Calendar") { env.calendar.requestAndLoad() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if env.calendar.access == .unknown { env.calendar.requestAndLoad() }
            else if env.calendar.access == .granted { env.calendar.load() }
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Palette.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
