import SwiftUI

/// Animation tokens and 3D-intensity helpers. Centralising easing keeps motion
/// consistent and makes the global "3D intensity" preference trivial to apply.
enum Motion {
    static let open = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let hover = Animation.spring(response: 0.28, dampingFraction: 0.8)
    static let tab = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let hud = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Max perspective tilt (degrees) for the hover lift before intensity scaling.
    static let baseTilt: Double = 6
    /// Max parallax translation (points) before intensity scaling.
    static let baseParallax: Double = 8

    static func tilt(_ factor: Double) -> Double { baseTilt * factor }
    static func parallax(_ factor: Double) -> Double { baseParallax * factor }

    /// Honour Low Power Mode by halving spring responsiveness when active.
    static var reducedPower: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

extension View {
    /// Applies a perspective "lift" used on hover/open. `amount` 0...1, scaled by intensity factor.
    func lift(_ amount: Double, parallax: CGSize, factor: Double) -> some View {
        let tilt = Motion.tilt(factor) * amount
        return self
            .rotation3DEffect(.degrees(parallax.height / 8 * factor * -1),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(parallax.width / 8 * factor),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .offset(x: parallax.width * 0.3 * factor, y: parallax.height * 0.3 * factor)
            .shadow(color: .black.opacity(0.5 * amount), radius: 18 * amount, y: 10 * amount)
            .scaleEffect(1 + 0.01 * tilt / max(Motion.baseTilt, 0.001))
    }
}
