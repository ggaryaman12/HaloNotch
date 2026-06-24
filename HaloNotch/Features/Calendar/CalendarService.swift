import EventKit
import Observation
import Foundation

/// Reads upcoming calendar events via EventKit. This includes any Google Calendar the
/// user has added in System Settings ▸ Internet Accounts (macOS syncs it into the
/// system calendar, so no Google OAuth/API is needed). Video-call links — Google Meet,
/// Zoom, Teams, Webex — are pulled out of each event so they can be joined straight
/// from the notch. Permission is requested lazily the first time the module is shown.
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
        let meetLink: URL?      // Google Meet / Zoom / Teams join URL, if any

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
            .prefix(6)
            .map { ek in
                Event(id: ek.eventIdentifier ?? UUID().uuidString,
                      title: ek.title ?? "(no title)",
                      start: ek.startDate,
                      isAllDay: ek.isAllDay,
                      meetLink: Self.conferenceLink(in: ek))
            }
    }

    /// Pull a video-call link out of an event's structured URL, notes, or location.
    /// Google Calendar usually drops the Meet link into the event URL; others embed it
    /// in the notes/body.
    private static func conferenceLink(in ek: EKEvent) -> URL? {
        // 1) A structured URL pointing at a known conferencing host wins outright.
        if let u = ek.url, let host = u.host?.lowercased(),
           host.contains("meet.google") || host.contains("zoom") || host.contains("teams.microsoft") || host.contains("webex") {
            return u
        }
        // 2) Otherwise scan the free-text fields for the first matching link.
        let haystack = [ek.url?.absoluteString, ek.notes, ek.location]
            .compactMap { $0 }
            .joined(separator: "\n")
        let patterns = [
            "https://meet\\.google\\.com/[a-z0-9-]+",
            "https://[a-z0-9.-]*zoom\\.us/j/[0-9]+(\\?[^\\s]*)?",
            "https://teams\\.microsoft\\.com/l/meetup-join/[^\\s]+",
            "https://[a-z0-9.-]*webex\\.com/[^\\s]+",
        ]
        for p in patterns {
            if let r = haystack.range(of: p, options: [.regularExpression, .caseInsensitive]) {
                return URL(string: String(haystack[r]))
            }
        }
        return nil
    }
}
