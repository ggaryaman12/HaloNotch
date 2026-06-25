import SwiftUI

/// Album artwork with rounded corners and a graceful gradient placeholder.
struct AlbumArtView: View {
    let image: NSImage?
    var size: CGFloat = 60

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.8)))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
            .strokeBorder(.white.opacity(0.14)))
    }
}

/// Expanded media module: artwork with color glow, metadata, scrub progress with
/// time labels, transport, and the visualizer. The card background is tinted by the
/// artwork's dominant color (computed once per track).
struct MediaView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var artColor: Color = .accentColor
    @State private var lastKey: String = ""

    private var np: NowPlaying? { env.media.nowPlaying }

    var body: some View {
        ZStack {
            if let np {
                // Color wash tinted by the album art.
                LinearGradient(colors: [artColor.opacity(0.35), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blur(radius: 8)
                    .allowsHitTesting(false)

                VStack(spacing: 8) {
                    HStack(spacing: 14) {
                        AlbumArtView(image: np.artwork, size: 72)
                            .shadow(color: artColor.opacity(0.7), radius: 14, y: 4)

                        VStack(alignment: .leading, spacing: 6) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(np.title).font(Theme.Typography.title).lineLimit(1)
                                Text(np.artist).font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Palette.textSecondary).lineLimit(1)
                            }
                            // Transport sits below the song name, above the progress.
                            HStack(spacing: 20) {
                                transport("backward.fill", 14) { env.media.previous() }
                                Button { env.media.playPause() } label: {
                                    Image(systemName: env.media.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(.white.opacity(0.16)))
                                }
                                .buttonStyle(.plain).foregroundStyle(.white)
                                transport("forward.fill", 14) { env.media.next() }
                                Spacer()
                                VisualizerView().frame(width: 40, height: 20)
                            }
                        }
                    }

                    progressBar(np)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "music.note.list").font(.title2)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text("Nothing playing").font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { refreshColor() }
        .onChange(of: np?.title) { _, _ in refreshColor() }
    }

    private func progressBar(_ np: NowPlaying) -> some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let frac = env.notch.scrubFraction ?? np.progress
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18)).frame(height: 4)
                    Capsule().fill(.white)
                        .frame(width: max(0, geo.size.width * frac), height: 4)
                        .animation(env.notch.scrubFraction == nil ? .linear(duration: 1) : nil, value: frac)
                    Circle().fill(.white)
                        .frame(width: env.notch.scrubFraction == nil ? 0 : 11, height: 11)
                        .offset(x: geo.size.width * frac - (env.notch.scrubFraction == nil ? 0 : 5.5))
                }
                // Publish the bar's window-local rect so NotchWindow can hit-test drags
                // (the panel isn't key, so a SwiftUI gesture can't drive the scrub).
                .onChange(of: geo.frame(in: .global)) { _, r in env.notch.progressBarRect = r }
                .onAppear { env.notch.progressBarRect = geo.frame(in: .global) }
            }
            .frame(height: 11)
            HStack {
                Text(timeString(np.elapsed)).font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Text(timeString(np.duration)).font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    private func transport(_ symbol: String, _ size: CGFloat, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: size)) }
            .buttonStyle(.plain).foregroundStyle(.white)
    }

    private func timeString(_ t: TimeInterval) -> String {
        guard t.isFinite, t > 0 else { return "0:00" }
        let s = Int(t); return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func refreshColor() {
        let key = np?.title ?? ""
        guard key != lastKey else { return }
        lastKey = key
        artColor = np?.artwork?.dominantColor ?? .accentColor
    }
}

extension NSImage {
    /// Average color of the image (downsampled to 1×1). Cheap dominant-color proxy.
    var dominantColor: Color {
        guard let tiff = tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff),
              let cg = bmp.cgImage,
              let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                                  bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return .accentColor }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let data = ctx.data else { return .accentColor }
        let p = data.bindMemory(to: UInt8.self, capacity: 4)
        return Color(.sRGB, red: Double(p[0]) / 255, green: Double(p[1]) / 255, blue: Double(p[2]) / 255)
    }
}
