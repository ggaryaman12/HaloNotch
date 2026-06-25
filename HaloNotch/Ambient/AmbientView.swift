import SwiftUI

/// Fullscreen "ambient" / sleep screen: blurred album-art backdrop, big clock,
/// now-playing card, and time-synced lyrics (LRCLIB). Toggled from the menu bar;
/// Esc or the close button dismisses it. Not the OS lock screen (apps can't draw
/// there) — an in-app ambient overlay, like NotchNook's fullscreen mode.
struct AmbientView: View {
    @Environment(AppEnvironment.self) private var env
    let onClose: () -> Void

    /// Fraction (0…1) being dragged on the scrubber, or nil when not scrubbing.
    @State private var scrub: Double?

    // ===== Tunable ambient dimensions (edit these) =====
    private let artWithLyrics: CGFloat = 320
    private let artNoLyrics: CGFloat = 400
    private let pairSpacing: CGFloat = 80
    private let lyricsWidth: CGFloat = 560
    private let clockSize: CGFloat = 128
    // ===================================================

    private var np: NowPlaying? { env.media.nowPlaying }
    private var hasLyrics: Bool { !env.lyrics.lines.isEmpty }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backdrop

                if hasLyrics {
                    // Two equal halves around the true center: song centered in the
                    // left half, lyrics centered in the right half.
                    HStack(spacing: 0) {
                        nowPlayingCard.frame(width: geo.size.width / 2)
                        lyricsPanel.frame(width: geo.size.width / 2)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    // No lyrics: song dead-center of the whole screen.
                    nowPlayingCard.frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .top) { clock.padding(.top, 56) }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 14) {
                    BatteryGlyph()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(28)
            }
            .overlay(alignment: .bottom) {
                Text("Press Esc to exit")
                    .font(.caption).foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 18)
            }
            .overlay(alignment: .bottom) {
                if env.claude.status == .waiting || env.claude.pendingQuestion != nil {
                    ClaudeView()
                        .frame(width: 540)
                        .padding(16)
                        .background(Theme.cardBackground(cornerRadius: 18))
                        .padding(.bottom, 56)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: env.claude.pendingQuestion)
        }
        .ignoresSafeArea()
        .onAppear { loadLyrics() }
        .onChange(of: np?.title) { _, _ in loadLyrics() }
    }

    // MARK: Backdrop

    @ViewBuilder private var backdrop: some View {
        ZStack {
            if let art = np?.artwork {
                Image(nsImage: art).resizable().scaledToFill()
                    .blur(radius: 80).saturation(1.4)
                    .overlay(Color.black.opacity(0.55))
            } else {
                LinearGradient(colors: [.black, Color(white: 0.12)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Clock

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(spacing: 2) {
                Text(ctx.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Text(ctx.date, format: .dateTime.hour().minute())
                    .font(.system(size: clockSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            }
        }
    }

    // MARK: Now playing

    private var nowPlayingCard: some View {
        let art: CGFloat = hasLyrics ? artWithLyrics : artNoLyrics
        return VStack(spacing: 22) {
            AlbumArtView(image: np?.artwork, size: art)
                .shadow(color: .black.opacity(0.65), radius: 40, y: 20)
                .id(np?.title)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))

            VStack(spacing: 5) {
                Text(np?.title ?? "Nothing playing")
                    .font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    .lineLimit(1)
                Text(np?.artist ?? "")
                    .font(.system(size: 19)).foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .id(np?.title)
            .transition(.opacity)

            if let np {
                GeometryReader { geo in
                    let frac = scrub ?? np.progress
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2)).frame(height: 5)
                        Capsule().fill(.white)
                            .frame(width: max(0, geo.size.width * frac), height: 5)
                            .animation(scrub == nil ? .linear(duration: 1) : nil, value: frac)
                        Circle().fill(.white)
                            .frame(width: scrub == nil ? 0 : 15, height: 15)
                            .offset(x: geo.size.width * frac - (scrub == nil ? 0 : 7.5))
                    }
                    .frame(height: 15)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in scrub = min(max(v.location.x / geo.size.width, 0), 1) }
                        .onEnded { v in
                            let f = min(max(v.location.x / geo.size.width, 0), 1)
                            if np.duration > 0 { env.media.seek(to: f * np.duration) }
                            scrub = nil
                        })
                }
                .frame(width: art, height: 15)
            }

            HStack(spacing: 40) {
                control("backward.fill", 24) { env.media.previous() }
                Button { env.media.playPause() } label: {
                    Image(systemName: env.media.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .frame(width: 66, height: 66)
                        .background(Circle().fill(.white.opacity(0.18)))
                }.buttonStyle(.plain).foregroundStyle(.white)
                control("forward.fill", 24) { env.media.next() }
            }
        }
        .frame(width: art + 40)
        .animation(.easeInOut(duration: 0.4), value: np?.title)
    }

    private func control(_ s: String, _ size: CGFloat, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Image(systemName: s).font(.system(size: size)) }
            .buttonStyle(.plain).foregroundStyle(.white.opacity(0.9))
    }

    // MARK: Lyrics

    @ViewBuilder private var lyricsPanel: some View {
        let elapsed = np?.elapsed ?? 0
        let current = env.lyrics.currentIndex(at: elapsed)
        if env.lyrics.lines.isEmpty {
            VStack {
                Text(env.lyrics.loading ? "Loading lyrics…" :
                        (env.lyrics.plain ?? "No synced lyrics for this track"))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.leading)
                    .lineLimit(8)
            }
            .frame(maxWidth: 460, alignment: .leading)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(env.lyrics.lines.enumerated()), id: \.element.id) { i, line in
                            Text(line.text)
                                .font(.system(size: 26, weight: i == current ? .bold : .medium))
                                .foregroundStyle(.white.opacity(i == current ? 1 : 0.32))
                                .id(i)
                                .animation(.easeInOut(duration: 0.25), value: current)
                        }
                    }
                    .padding(.vertical, 160)
                }
                .frame(maxWidth: lyricsWidth, maxHeight: 420)
                .mask(LinearGradient(colors: [.clear, .black, .black, .clear],
                                     startPoint: .top, endPoint: .bottom))
                .onChange(of: current) { _, new in
                    guard let new else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }
        }
    }

    private func loadLyrics() {
        guard let np else { return }
        env.lyrics.load(artist: np.artist, title: np.title, album: np.album, duration: np.duration)
    }
}
