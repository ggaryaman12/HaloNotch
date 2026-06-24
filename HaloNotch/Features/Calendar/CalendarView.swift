import SwiftUI

/// Expanded calendar module: next events with countdowns, or a permission prompt.
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
                            HStack {
                                Circle().fill(.white.opacity(0.5)).frame(width: 6, height: 6)
                                Text(event.title).font(Theme.Typography.body).lineLimit(1)
                                Spacer()
                                Text(event.isAllDay ? "all day" : event.countdown)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
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
