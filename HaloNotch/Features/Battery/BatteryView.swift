import SwiftUI

/// Battery indicator. Compact mode (notch idle/hover) shows a colored percentage;
/// full mode (e.g. settings/expanded) adds an SF battery glyph and charging bolt.
struct BatteryGlyph: View {
    @Environment(AppEnvironment.self) private var env
    var compact: Bool = false

    private var color: Color {
        if env.battery.isCharging { return Theme.Palette.good }
        if env.battery.isLow { return Theme.Palette.danger }
        if env.battery.percent <= 40 { return Theme.Palette.warn }
        return .white
    }

    var body: some View {
        HStack(spacing: 3) {
            if !compact {
                Image(systemName: symbol)
                    .foregroundStyle(color)
            }
            if env.battery.isCharging && compact {
                Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundStyle(color)
            }
            Text("\(env.battery.percent)%")
                .font(Theme.Typography.mono)
                .foregroundStyle(color)
        }
    }

    private var symbol: String {
        if env.battery.isCharging { return "battery.100.bolt" }
        switch env.battery.percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default:    return "battery.100"
        }
    }
}
