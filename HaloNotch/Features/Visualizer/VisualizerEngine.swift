import Foundation
import Observation

/// Produces normalized bar levels (0...1) for the visualizer. Currently synthesizes
/// levels from playback state (animated while playing, gently "breathing" when
/// paused). Architected to accept real FFT samples later via `ingest(_:)`.
@Observable
final class VisualizerEngine {
    private(set) var levels: [Double] = Array(repeating: 0.2, count: 7)

    private var timer: Timer?
    private var isPlayingProvider: () -> Bool = { false }
    private var phase: Double = 0

    /// Connects the engine to a playback-state source and starts ticking.
    func bind(isPlaying: @escaping () -> Bool) {
        isPlayingProvider = isPlaying
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// Feed real audio magnitudes (already bucketed to `levels.count`). Optional path.
    func ingest(_ samples: [Double]) {
        guard samples.count == levels.count else { return }
        levels = samples.map { min(max($0, 0), 1) }
    }

    private func tick() {
        phase += 0.22
        let playing = isPlayingProvider()
        for i in levels.indices {
            if playing {
                let base = (sin(phase + Double(i) * 0.7) + 1) / 2
                let noise = Double.random(in: 0...0.35)
                levels[i] = min(1, base * 0.65 + noise)
            } else {
                let breathe = (sin(phase * 0.4) + 1) / 2 * 0.14 + 0.06
                levels[i] = levels[i] * 0.82 + breathe * 0.18
            }
        }
    }
}
