import SwiftUI

/// Design tokens: color, typography, spacing, radii. Keep all magic numbers here.
enum Theme {
    enum Metrics {
        static let cornerRadius: CGFloat = 18
        static let notchCornerRadius: CGFloat = 12
        static let padding: CGFloat = 14
        static let chipSize: CGFloat = 56
        /// Closed notch overscan (points added around the physical notch for hit testing).
        static let closedInset: CGFloat = 0
    }

    enum Palette {
        static let surface = Color.black
        static let surfaceTop = Color(white: 0.10)
        static let stroke = Color.white.opacity(0.08)
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.6)
        static let good = Color.green
        static let warn = Color.yellow
        static let danger = Color.red
    }

    enum Typography {
        static let mono = Font.system(.caption, design: .rounded).monospacedDigit()
        static let title = Font.system(.headline, design: .rounded)
        static let body = Font.system(.subheadline, design: .rounded)
        static let caption = Font.system(.caption2, design: .rounded)
    }

    /// Glassy dark card background used by the expanded notch.
    static func cardBackground(cornerRadius: CGFloat = Metrics.cornerRadius) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.black)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.06), .clear],
                                       startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1))
    }
}

extension Color {
    /// Parse `#RRGGBB`. Returns accent fallback on bad input.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v & 0xFF0000) >> 16) / 255
            g = Double((v & 0x00FF00) >> 8) / 255
            b = Double(v & 0x0000FF) / 255
        } else { r = 0.40; g = 0.45; b = 0.95 }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
