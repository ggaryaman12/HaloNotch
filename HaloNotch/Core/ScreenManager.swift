import AppKit

/// Resolves the physical notch geometry on the active display, or synthesizes a
/// centered "pill" on displays without a notch. All rects are in global
/// (bottom-left origin) screen coordinates.
struct NotchMetrics {
    var screen: NSScreen
    var hasNotch: Bool
    /// Closed-state rect, pinned to the top center of the screen.
    var closedRect: CGRect

    /// Top edge y (global) that all states pin to.
    var topY: CGFloat { closedRect.maxY }
    var centerX: CGFloat { closedRect.midX }
}

enum ScreenManager {
    /// Fallback pill size for non-notch Macs / external displays.
    static let fallbackSize = CGSize(width: 220, height: 32)

    static func currentMetrics() -> NotchMetrics {
        let screen = menuBarScreen()
        let frame = screen.frame

        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           screen.safeAreaInsets.top > 0 {
            let notchWidth = max(right.minX - left.maxX, 120)
            let notchHeight = screen.safeAreaInsets.top
            let rect = CGRect(x: frame.midX - notchWidth / 2,
                              y: frame.maxY - notchHeight,
                              width: notchWidth,
                              height: notchHeight)
            return NotchMetrics(screen: screen, hasNotch: true, closedRect: rect)
        }

        // No notch: floating pill just under the top edge.
        let size = fallbackSize
        let rect = CGRect(x: frame.midX - size.width / 2,
                          y: frame.maxY - size.height,
                          width: size.width, height: size.height)
        return NotchMetrics(screen: screen, hasNotch: false, closedRect: rect)
    }

    /// The screen that owns the menu bar (where the notch lives).
    private static func menuBarScreen() -> NSScreen {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }
}
