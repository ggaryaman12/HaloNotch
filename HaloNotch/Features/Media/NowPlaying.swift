import AppKit

/// Immutable snapshot of the system "Now Playing" state.
struct NowPlaying: Equatable {
    var title: String
    var artist: String
    var album: String
    var artwork: NSImage?
    var duration: TimeInterval
    var elapsed: TimeInterval

    static func == (l: NowPlaying, r: NowPlaying) -> Bool {
        l.title == r.title && l.artist == r.artist && l.album == r.album &&
        l.duration == r.duration && abs(l.elapsed - r.elapsed) < 0.5 &&
        l.artwork === r.artwork
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }
}
