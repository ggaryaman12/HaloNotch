import SwiftUI

/// First-run (and replayable) onboarding. A flat bar morphs into a 3D "portal"
/// that introduces features across paged cards with parallax + perspective.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let blurb: String
    }

    private let pages: [Page] = [
        .init(symbol: "rectangle.topthird.inset.filled", title: "Welcome to HaloNotch",
              blurb: "Your notch, reimagined. Glanceable when idle, powerful on hover."),
        .init(symbol: "music.note", title: "Music & Visualizer",
              blurb: "Control playback and watch the beat right from the notch."),
        .init(symbol: "tray.full", title: "File Shelf",
              blurb: "Flick files up to the notch to stash, then drag out or AirDrop."),
        .init(symbol: "calendar", title: "Calendar & Battery",
              blurb: "Your next meeting and power status, always a glance away."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(white: 0.08)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 28) {
                Portal(symbol: pages[page].symbol)
                    .frame(height: 220)
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.6).combined(with: .opacity),
                        removal: .opacity))

                VStack(spacing: 8) {
                    Text(pages[page].title)
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Text(pages[page].blurb)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .foregroundStyle(.white)

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.accentColor : .white.opacity(0.25))
                            .frame(width: i == page ? 22 : 7, height: 7)
                    }
                }

                HStack {
                    Button("Skip", action: onFinish)
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    Spacer()
                    Button(page == pages.count - 1 ? "Get Started" : "Next") {
                        if page == pages.count - 1 { onFinish() }
                        else { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { page += 1 } }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: 420)
            }
            .padding(40)
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}

/// A rotating 3D "portal" ring around a feature glyph. Continuously animates with a
/// gentle perspective tilt — the signature onboarding effect.
private struct Portal: View {
    let symbol: String
    @State private var spin = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { ring in
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [.purple, .pink, .orange, .purple], center: .center),
                        lineWidth: 6 - CGFloat(ring) * 1.5)
                    .frame(width: 180 - CGFloat(ring) * 36, height: 180 - CGFloat(ring) * 36)
                    .rotation3DEffect(.degrees(spin ? 360 : 0),
                                      axis: (x: 0.4, y: 1, z: 0.2 * Double(ring + 1)))
                    .opacity(1 - Double(ring) * 0.2)
            }
            Image(systemName: symbol)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .purple.opacity(0.6), radius: 18)
                .scaleEffect(spin ? 1.05 : 0.95)
        }
        .onAppear {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}
