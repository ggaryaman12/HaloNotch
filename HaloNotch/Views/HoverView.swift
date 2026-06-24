import SwiftUI

/// Collects hover transport-control frames (window-local, top-left) so NotchWindow's
/// global mouse monitor can hit-test them (SwiftUI Buttons can't receive clicks while
/// the panel is intentionally non-key).
struct MediaRectKey: PreferenceKey {
    static var defaultValue: [NotchViewModel.MediaButton: CGRect] = [:]
    static func reduce(value: inout [NotchViewModel.MediaButton: CGRect],
                       nextValue: () -> [NotchViewModel.MediaButton: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Hover glance: a compact now-playing strip shown BELOW the notch band. Album
/// thumbnail, title/artist, transport controls (prev / play-pause / next), and battery,
/// over a slow color wash tinted by the album art — like the expanded card.
struct HoverView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var artColor: Color = .accentColor
    @State private var lastKey = ""
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 10) {
            AlbumArtView(image: env.media.nowPlaying?.artwork, size: 34)
                .shadow(color: artColor.opacity(0.7), radius: 8, y: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text(env.media.nowPlaying?.title ?? "HaloNotch")
                    .font(Theme.Typography.body.weight(.semibold))
                    .lineLimit(1)
                Text(env.media.nowPlaying?.artist ?? "Click to open")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            HStack(spacing: 10) {
                control("backward.fill", .prev, size: 13)
                control(env.media.isPlaying ? "pause.fill" : "play.fill", .playPause, size: 16)
                control("forward.fill", .next, size: 13)
            }

            if env.preferences.batteryEnabled { BatteryGlyph(compact: true) }
        }
        .foregroundStyle(.white)
        .background(colorWash)
        .onPreferenceChange(MediaRectKey.self) { rects in
            env.notch.mediaRects = rects
        }
        .onAppear { refreshColor(); shimmer = true }
        .onChange(of: env.media.nowPlaying?.title) { _, _ in
            withAnimation(.easeInOut(duration: 0.7)) { refreshColor() }
        }
    }

    /// A song-tinted gradient that slowly drifts corner-to-corner.
    private var colorWash: some View {
        LinearGradient(colors: [artColor.opacity(0.55), artColor.opacity(0.18), .clear],
                       startPoint: shimmer ? .topLeading : .bottomLeading,
                       endPoint: shimmer ? .bottomTrailing : .topTrailing)
            .blur(radius: 16)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: shimmer)
            .animation(.easeInOut(duration: 0.7), value: artColor)
            .padding(-8)
    }

    /// A transport icon that publishes its window-local frame for the AppKit hit-test.
    @ViewBuilder
    private func control(_ symbol: String, _ button: NotchViewModel.MediaButton, size: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Circle().fill(.white.opacity(0.14)))
            .contentShape(Circle())
            .background(GeometryReader { g in
                Color.clear.preference(key: MediaRectKey.self, value: [button: g.frame(in: .global)])
            })
            .id(button == .playPause ? (env.media.isPlaying ? "pause" : "play") : symbol)
            .transition(.scale.combined(with: .opacity))
            .animation(Motion.hover, value: env.media.isPlaying)
    }

    private func refreshColor() {
        let key = env.media.nowPlaying?.title ?? ""
        guard key != lastKey else { return }
        lastKey = key
        artColor = env.media.nowPlaying?.artwork?.dominantColor ?? .accentColor
    }
}
