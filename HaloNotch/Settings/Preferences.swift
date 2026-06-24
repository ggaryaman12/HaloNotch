import SwiftUI
import Observation

/// Persisted, observable user preferences. UserDefaults-backed; every property
/// writes through on `didSet`. Safe to read before `start()`.
@Observable
final class Preferences {
    enum ThreeDIntensity: String, CaseIterable, Identifiable {
        case off, subtle, balanced, dramatic
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        /// Multiplier applied to perspective/parallax magnitudes.
        var factor: Double {
            switch self {
            case .off: return 0
            case .subtle: return 0.5
            case .balanced: return 1.0
            case .dramatic: return 1.6
            }
        }
    }

    private let defaults = UserDefaults.standard

    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") } }
    var mediaEnabled: Bool { didSet { defaults.set(mediaEnabled, forKey: "mediaEnabled") } }
    var calendarEnabled: Bool { didSet { defaults.set(calendarEnabled, forKey: "calendarEnabled") } }
    var shelfEnabled: Bool { didSet { defaults.set(shelfEnabled, forKey: "shelfEnabled") } }
    var batteryEnabled: Bool { didSet { defaults.set(batteryEnabled, forKey: "batteryEnabled") } }
    var hudEnabled: Bool { didSet { defaults.set(hudEnabled, forKey: "hudEnabled") } }
    var demoMediaFallback: Bool { didSet { defaults.set(demoMediaFallback, forKey: "demoMediaFallback") } }
    var ambientOnIdle: Bool { didSet { defaults.set(ambientOnIdle, forKey: "ambientOnIdle") } }
    var accentHex: String { didSet { defaults.set(accentHex, forKey: "accentHex") } }

    var threeDIntensity: ThreeDIntensity {
        didSet { defaults.set(threeDIntensity.rawValue, forKey: "threeDIntensity") }
    }

    init() {
        defaults.register(defaults: [
            "mediaEnabled": true, "calendarEnabled": true, "shelfEnabled": true,
            "batteryEnabled": true, "hudEnabled": true, "demoMediaFallback": true,
            "ambientOnIdle": false,
            "accentHex": "#6673F2", "threeDIntensity": ThreeDIntensity.balanced.rawValue,
        ])
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        mediaEnabled = defaults.bool(forKey: "mediaEnabled")
        calendarEnabled = defaults.bool(forKey: "calendarEnabled")
        shelfEnabled = defaults.bool(forKey: "shelfEnabled")
        batteryEnabled = defaults.bool(forKey: "batteryEnabled")
        hudEnabled = defaults.bool(forKey: "hudEnabled")
        demoMediaFallback = defaults.bool(forKey: "demoMediaFallback")
        ambientOnIdle = defaults.bool(forKey: "ambientOnIdle")
        accentHex = defaults.string(forKey: "accentHex") ?? "#6673F2"
        threeDIntensity = ThreeDIntensity(rawValue: defaults.string(forKey: "threeDIntensity") ?? "balanced") ?? .balanced
    }
}
