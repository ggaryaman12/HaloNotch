import SwiftUI
import Observation

/// Owns the notch UI state machine and the currently selected expanded tab.
/// Mouse tracking is performed by `NotchWindow`, which calls `send(_:)`.
@Observable
final class NotchViewModel {
    enum Tab: String, CaseIterable, Identifiable {
        case media, calendar, shelf, claude
        var id: String { rawValue }
        var title: String { self == .claude ? "Claude" : rawValue.capitalized }
        var symbol: String {
            switch self {
            case .media: return "music.note"
            case .calendar: return "calendar"
            case .shelf: return "tray.full"
            case .claude: return "sparkles"
            }
        }
    }

    private(set) var state: NotchState = .closed
    var selectedTab: Tab = .media

    /// Normalised cursor offset within the notch rect (-1...1) for parallax. Updated on hover.
    var parallax: CGSize = .zero

    /// Physical notch size, set by the window once geometry is known. Single source of
    /// truth so the window's hit-testing and the SwiftUI layout always agree.
    var closedSize: CGSize = CGSize(width: 200, height: 32)

    /// Target visual size of the notch card for a given state. Heights include the
    /// physical-notch band at top; real content is laid out BELOW that band so it
    /// drops down past the notch (Dynamic-Island style) instead of hiding behind it.
    func size(for state: NotchState) -> CGSize {
        switch state {
        case .closed:  return closedSize
        case .hovered: return CGSize(width: closedSize.width + 180, height: closedSize.height + 60)
        case .open:    return CGSize(width: max(420, closedSize.width + 205), height: closedSize.height + 178)
        }
    }

    /// Height of the physical-notch band content must clear.
    var notchBand: CGFloat { closedSize.height }

    /// Feed an event through the reducer with animation.
    func send(_ event: NotchState.Event) {
        let next = state.reduce(event)
        guard next != state else { return }
        if ProcessInfo.processInfo.environment["HALO_DEBUG"] != nil {
            FileHandle.standardError.write("notch: \(state) -[\(event)]-> \(next)\n".data(using: .utf8)!)
        }
        state = next
        if next == .closed { parallax = .zero }
    }

    func select(_ tab: Tab) { selectedTab = tab }

    /// While now < pinnedUntil, the notch won't auto-close on mouse-exit (used so a
    /// programmatic pop-out stays visible long enough to read/answer).
    var pinnedUntil: Date = .distantPast

    /// Window-local (top-left origin) rects of the current answer buttons, keyed by
    /// option index. Published by the SwiftUI answer view and hit-tested by NotchWindow,
    /// so a click works regardless of the panel's key/first-mouse state.
    var answerRects: [Int: CGRect] = [:]

    enum MediaButton: Hashable { case prev, playPause, next }
    /// Same idea as `answerRects` but for the hover-strip transport controls.
    var mediaRects: [MediaButton: CGRect] = [:]

    /// Join-button rects for calendar events with a meeting link, keyed by event id.
    var joinRects: [String: CGRect] = [:]

    /// Force the notch open on a given tab (used when Claude needs attention).
    func present(_ tab: Tab) {
        selectedTab = tab
        pinnedUntil = Date().addingTimeInterval(20)
        if state != .open { state = .open }
    }
}
