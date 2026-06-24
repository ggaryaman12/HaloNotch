import SwiftUI

/// Left-edge volume/brightness slider, styled after macOS's own edge HUD: a light
/// frosted pill flush to the screen edge (flat left, rounded right), with the level
/// filling from the bottom and an icon beneath it. It PUSHES IN from the edge on
/// change and retracts when done; `HUDManager` fires a Force Touch haptic per step.
struct VolumeBarView: View {
    @Environment(HUDManager.self) private var hud
    @State private var bump = false

    private var icon: String {
        if hud.value <= 0.001 { return "speaker.slash.fill" }
        if hud.value < 0.33 { return "speaker.fill" }
        if hud.value < 0.66 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                               bottomTrailingRadius: 17, topTrailingRadius: 17,
                               style: .continuous)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle()
                    .fill(.white)
                    .frame(height: max(8, geo.size.height * hud.value))
                    .animation(.spring(response: 0.3, dampingFraction: 0.72), value: hud.value)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
                    .padding(.bottom, 10)
                    .contentTransition(.symbolEffect(.replace))
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 1))
        }
        .environment(\.colorScheme, .light)
        .padding(.vertical, 14)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 4, y: 0)
        // Push in FROM the left edge; retract off-edge when hidden.
        .offset(x: hud.visible ? 0 : -48)
        .scaleEffect(x: bump ? 1.12 : 1, y: bump ? 1.02 : 1, anchor: .leading)
        .opacity(hud.visible ? 1 : 0)
        .animation(.spring(response: 0.34, dampingFraction: 0.74), value: hud.visible)
        .onChange(of: hud.pulse) { _, _ in
            withAnimation(.spring(response: 0.14, dampingFraction: 0.45)) { bump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { bump = false }
            }
        }
    }
}
