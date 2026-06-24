import Foundation

/// The notch's visible interaction state. Pure value type so transition logic is
/// trivially unit-testable without any UI.
enum NotchState: Equatable {
    case closed
    case hovered
    case open

    /// Input events the state machine reacts to.
    enum Event: Equatable {
        case mouseEntered
        case mouseExited
        case clicked
        case dismissed   // click outside / Esc
    }

    /// Returns the next state for an event. Centralised so it can be tested in isolation.
    func reduce(_ event: Event) -> NotchState {
        switch (self, event) {
        case (.closed, .mouseEntered): return .hovered
        case (.hovered, .mouseExited): return .closed
        case (.hovered, .clicked):     return .open
        case (.closed, .clicked):      return .open
        case (.open, .dismissed):      return .closed
        case (.open, .mouseExited):    return .open      // stay open until dismissed
        default:                       return self
        }
    }

    var isExpanded: Bool { self == .open }
    var isInteractive: Bool { self != .closed }
}
