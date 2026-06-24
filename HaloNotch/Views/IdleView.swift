import SwiftUI

/// Closed-notch ambient content. When audio plays, a small album-art thumbnail peeks
/// on the left and an equalizer pulses on the right — so the notch looks alive even
/// at rest. Center stays clear for the physical camera. Battery sits far right.
struct IdleView: View {
    @Environment(AppEnvironment.self) private var env

    private var playing: Bool { env.preferences.mediaEnabled && env.media.isPlaying }
    private var claudeActive: Bool { env.claude.status == .working || env.claude.status == .waiting }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if claudeActive {
                    ClaudePulse()
                        .transition(.opacity.combined(with: .scale))
                } else if playing, let np = env.media.nowPlaying {
                    AlbumArtView(image: np.artwork, size: 20)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 22) // camera gap

            HStack(spacing: 7) {
                if playing {
                    MiniEqualizer()
                        .frame(width: 16, height: 11)
                        .transition(.opacity)
                }
                if env.preferences.batteryEnabled {
                    BatteryGlyph(compact: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .foregroundStyle(.white)
        .animation(Motion.hover, value: playing)
        .animation(Motion.hover, value: claudeActive)
    }
}
