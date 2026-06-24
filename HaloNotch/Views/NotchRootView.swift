import SwiftUI

/// Dynamic-Island-style silhouette. `topRadius` rounds the top "shoulders" (0 hugs
/// the bezel for the closed notch); `bottomRadius` rounds the bottom.
struct NotchShape: Shape {
    var topRadius: CGFloat = 0
    var bottomRadius: CGFloat = Theme.Metrics.notchCornerRadius

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tr = min(topRadius, rect.height / 2, rect.width / 2)
        let br = min(bottomRadius, rect.height / 2, rect.width / 2)

        p.move(to: CGPoint(x: rect.minX, y: rect.minY + tr))
        if tr > 0 {
            p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY),
                           control: CGPoint(x: rect.minX, y: rect.minY))
        }
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                           control: CGPoint(x: rect.maxX, y: rect.minY))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - br),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Top-level notch content. Hosted in a fixed-size window; this view draws the notch
/// card anchored to the top center and grows it downward as the state changes. Hover
/// and click are handled by `NotchWindow`'s global mouse monitors, not SwiftUI.
struct NotchRootView: View {
    @Environment(AppEnvironment.self) private var env

    private var claudeActive: Bool {
        env.claude.status == .working || env.claude.status == .waiting
    }

    var body: some View {
        let state = env.notch.state
        let size = env.notch.size(for: state)
        let factor = env.preferences.threeDIntensity.factor

        let expanded = state != .closed

        let shape = NotchShape(topRadius: expanded ? 14 : 0,
                               bottomRadius: expanded ? 26 : Theme.Metrics.notchCornerRadius)

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                shape.fill(.black)
                    .shadow(color: .black.opacity(expanded ? 0.55 : 0),
                            radius: 18, y: 10)
                shape
                    .stroke(Theme.Palette.stroke, lineWidth: 1)
                    .opacity(expanded ? 1 : 0)

                // Content drops BELOW the physical-notch band so it isn't hidden by it.
                content(for: state)
                    .padding(.top, expanded ? env.notch.notchBand + 6 : 2)
                    .padding(.horizontal, state == .open ? Theme.Metrics.padding : 10)
                    .padding(.bottom, expanded ? Theme.Metrics.padding : 3)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(width: size.width, height: size.height)
            .lift(expanded ? 1 : 0, parallax: env.notch.parallax, factor: factor)

            // While closed, a small Claude pill drops just below the physical notch so
            // thinking/waiting activity is visible (the closed band itself sits hidden
            // behind the hardware notch).
            if state == .closed && claudeActive {
                ClaudePeek()
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Motion.open, value: state)
        .animation(Motion.open, value: claudeActive)
    }

    @ViewBuilder
    private func content(for state: NotchState) -> some View {
        switch state {
        case .closed:  IdleView()
        case .hovered: HoverView()
        case .open:    ExpandedView()
        }
    }
}
