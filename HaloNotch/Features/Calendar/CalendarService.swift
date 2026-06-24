import EventKit
import Observation

/// Reads upcoming calendar events via EventKit. Permission is requested lazily the
/// first time the calendar module is shown; denial degrades to an inline prompt.
@Observable
final class CalendarService {
    enum Access { case unknown, granted, denied }

    private(set) var access: Access = .unknown
    private(set) var upcoming: [Event] = []

    private let store = EKEventStore()

    /// Lightweight value snapshot so views don't depend on EventKit types.
    struct Event: Identifiable {
        let id: String
        let title: String
        let start: Date
        let isAllDay: Bool
        var countdown: String {
            let delta = start.timeIntervalSinceNow
            if delta < 0 { return "now" }
            let mins = Int(delta / 60)
            if mins < 60 { return "in \(max(mins, 1))m" }
            let hrs = mins / 60
            return "in \(hrs)h \(mins % 60)m"
        }
    }

    func requestAndLoad() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.access = granted ? .granted : .denied
                if granted { self.load() }
            }
        }
    }

    func load() {
        let now = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: 2, to: now) else { return }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        upcoming = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
            .map { Event(id: $0.eventIdentifier ?? UUID().uuidString,
                         title: $0.title ?? "(no title)",
                         start: $0.startDate,
                         isAllDay: $0.isAllDay) }
    }
}
