import XCTest
@testable import HaloNotch

final class MediaControllerTests: XCTestCase {
    func testMockStartsPlaying() {
        let c = MockMediaController(playing: true)
        XCTAssertTrue(c.isPlaying)
        XCTAssertNotNil(c.nowPlaying)
    }

    func testPlayPauseToggles() {
        let c = MockMediaController(playing: true)
        c.playPause()
        XCTAssertFalse(c.isPlaying)
        c.playPause()
        XCTAssertTrue(c.isPlaying)
    }

    func testNowPlayingProgress() {
        let np = NowPlaying(title: "t", artist: "a", album: "al",
                            artwork: nil, duration: 100, elapsed: 25)
        XCTAssertEqual(np.progress, 0.25, accuracy: 0.001)
    }

    func testProgressZeroWhenNoDuration() {
        let np = NowPlaying(title: "t", artist: "a", album: "al",
                            artwork: nil, duration: 0, elapsed: 25)
        XCTAssertEqual(np.progress, 0)
    }
}
