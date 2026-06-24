import AppKit
import Observation

/// Reads system "Now Playing" via the private `MediaRemote` framework, resolved at
/// runtime with `dlopen`/`dlsym` (no bundled binary). Polls once per second and also
/// reacts to the system's change notifications. If nothing is playing and the demo
/// fallback is enabled, a clearly-labelled demo track drives the UI — but the moment
/// real audio appears, the controller switches to it.
@Observable
final class MediaRemoteController: MediaController {
    private(set) var nowPlaying: NowPlaying?
    private(set) var isPlaying: Bool = false

    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias SendCommandFn = @convention(c) (Int, CFDictionary?) -> Bool

    private var getInfo: GetInfoFn?
    private var sendCommand: SendCommandFn?

    private var demoFallback = true
    private var usingDemo = false
    private var pollTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    // MARK: Lifecycle

    func start(demoFallback: Bool) {
        self.demoFallback = demoFallback
        if loadSymbols() {
            for name in ["kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                         "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"] {
                let obs = NotificationCenter.default.addObserver(
                    forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                    self?.tick()
                }
                observers.append(obs)
            }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    // MARK: Symbol resolution

    private func loadSymbols() -> Bool {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_NOW) else { return false }
        func sym(_ name: String) -> UnsafeMutableRawPointer? { dlsym(handle, name) }
        guard let g = sym("MRMediaRemoteGetNowPlayingInfo") else { return false }
        getInfo = unsafeBitCast(g, to: GetInfoFn.self)
        if let r = sym("MRMediaRemoteRegisterForNowPlayingNotifications") {
            unsafeBitCast(r, to: RegisterFn.self)(DispatchQueue.main)
        }
        if let s = sym("MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(s, to: SendCommandFn.self)
        }
        return true
    }

    // MARK: Polling

    private static let debug = ProcessInfo.processInfo.environment["HALO_DEBUG"] != nil
    private func log(_ s: String) {
        if Self.debug { FileHandle.standardError.write("media: \(s)\n".data(using: .utf8)!) }
    }

    private func tick() {
        guard let getInfo else { log("no getInfo symbol"); fallback(); return }
        getInfo(DispatchQueue.main) { [weak self] info in
            guard let self else { return }
            self.log("callback count=\(info.count) title=\(info["kMRMediaRemoteNowPlayingInfoTitle"] ?? "nil")")
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String
            if let title, !title.isEmpty {
                // Real audio present — take over from any demo.
                self.usingDemo = false
                let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
                let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 0
                let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0
                let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 1
                var art: NSImage?
                if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                    art = NSImage(data: data)
                }
                self.nowPlaying = NowPlaying(title: title, artist: artist, album: album,
                                            artwork: art, duration: duration, elapsed: elapsed)
                self.isPlaying = rate > 0
            } else {
                self.fallback()
            }
        }
    }

    private func fallback() {
        guard demoFallback else { nowPlaying = nil; isPlaying = false; return }
        if !usingDemo {
            usingDemo = true
            isPlaying = true
            nowPlaying = NowPlaying(title: "Midnight Drive", artist: "HaloNotch (demo)",
                                    album: "Neon Nights", artwork: Self.demoArtwork(),
                                    duration: 214, elapsed: 0)
        } else if isPlaying, var np = nowPlaying {
            np.elapsed = np.elapsed + 1 > np.duration ? 0 : np.elapsed + 1
            nowPlaying = np
        }
    }

    // MARK: Commands

    func playPause() {
        if usingDemo { isPlaying.toggle(); return }
        _ = sendCommand?(2, nil) // kMRTogglePlayPause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.tick() }
    }
    func next() {
        if usingDemo { if var np = nowPlaying { np.elapsed = 0; nowPlaying = np }; return }
        _ = sendCommand?(4, nil) // kMRNextTrack
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.tick() }
    }
    func previous() {
        if usingDemo { return }
        _ = sendCommand?(5, nil) // kMRPreviousTrack
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.tick() }
    }

    // MARK: Demo artwork

    private static func demoArtwork() -> NSImage {
        let size = NSSize(width: 256, height: 256)
        let img = NSImage(size: size)
        img.lockFocus()
        let g = NSGradient(colors: [NSColor.systemIndigo, NSColor.systemPink, NSColor.systemOrange])
        g?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
        img.unlockFocus()
        return img
    }
}
