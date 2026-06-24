import Foundation

/// Abstraction over a source of system media playback. Implemented by
/// `MediaRemoteController` (real) and `MockMediaController` (previews/tests).
protocol MediaController: AnyObject {
    var nowPlaying: NowPlaying? { get }
    var isPlaying: Bool { get }

    func start(demoFallback: Bool)
    func playPause()
    func next()
    func previous()
}

import Observation

/// Deterministic controller for SwiftUI previews and unit tests.
@Observable
final class MockMediaController: MediaController {
    private(set) var nowPlaying: NowPlaying?
    private(set) var isPlaying: Bool = true

    init(playing: Bool = true) {
        isPlaying = playing
        nowPlaying = NowPlaying(title: "Preview Track", artist: "HaloNotch",
                                album: "Demo", artwork: nil, duration: 200, elapsed: 42)
    }
    func start(demoFallback: Bool) {}
    func playPause() { isPlaying.toggle() }
    func next() {}
    func previous() {}
}
