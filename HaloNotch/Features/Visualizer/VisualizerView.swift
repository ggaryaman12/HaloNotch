import SwiftUI

/// Full visualizer: a row of bars driven by `VisualizerEngine.levels`.
struct VisualizerView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(env.visualizer.levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(LinearGradient(colors: [.white, .white.opacity(0.6)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: max(2, CGFloat(level) * 22))
            }
        }
        .frame(maxHeight: 22, alignment: .center)
        .animation(.linear(duration: 0.06), value: env.visualizer.levels)
    }
}

/// Compact 3-bar equalizer for the idle/hover states.
struct MiniEqualizer: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: max(2, CGFloat(level(i)) * 11))
            }
        }
        .frame(height: 11, alignment: .bottom)
        .animation(.linear(duration: 0.08), value: env.visualizer.levels)
    }

    private func level(_ i: Int) -> Double {
        let l = env.visualizer.levels
        return l.isEmpty ? 0.3 : l[i % l.count]
    }
}
