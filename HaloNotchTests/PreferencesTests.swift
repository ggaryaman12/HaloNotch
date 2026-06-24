import XCTest
import SwiftUI
@testable import HaloNotch

final class PreferencesTests: XCTestCase {
    func testThreeDIntensityFactors() {
        XCTAssertEqual(Preferences.ThreeDIntensity.off.factor, 0)
        XCTAssertGreaterThan(Preferences.ThreeDIntensity.dramatic.factor,
                             Preferences.ThreeDIntensity.subtle.factor)
    }

    func testPersistenceRoundTrip() {
        let prefs = Preferences()
        prefs.mediaEnabled = false
        prefs.accentHex = "#112233"
        // A fresh instance reads the same UserDefaults store.
        let reloaded = Preferences()
        XCTAssertFalse(reloaded.mediaEnabled)
        XCTAssertEqual(reloaded.accentHex, "#112233")
        // Restore defaults so the test is idempotent.
        prefs.mediaEnabled = true
        prefs.accentHex = "#6673F2"
    }

    func testColorHexParsing() {
        // Should not crash on malformed input.
        _ = Color(hex: "nonsense")
        _ = Color(hex: "#ABC")
        _ = Color(hex: "#00FF00")
    }
}
