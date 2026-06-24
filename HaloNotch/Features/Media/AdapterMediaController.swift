import AppKit
import Observation

/// Real system Now Playing via the bundled `mediaremote-adapter` (an Apple-signed
/// `/usr/bin/perl` host loads the adapter framework, which the OS still trusts —
/// unlike our ad-hoc app calling MediaRemote directly, which returns nothing on
/// macOS 15.4+). We spawn `perl … stream` and parse its JSON snapshots. Falls back
/// to a labelled demo track only if the adapter can't be located/launched.
@Observable
final class AdapterMediaController: MediaController {
    private(set) var nowPlaying: NowPlaying?
    private(set) var isPlaying: Bool = false

    private var process: Process?
    private var buffer = Data()
    private var demoFallback = true
    private var usingDemo = false
    private var demoTimer: Timer?

    private var plURL: URL?
    private var frameworkURL: URL?
    private var progressTimer: Timer?

    // Position is anchored to the snapshot's timestamp so the slider/lyrics track the
    // real song position: live = baseElapsed + (now - anchor) while playing.
    private var baseElapsed: Double = 0
    private var anchor = Date()
    private var emptyWork: DispatchWorkItem?
    private static let isoFormatter = ISO8601DateFormatter()

    // MARK: Lifecycle

    func start(demoFallback: Bool) {
        self.demoFallback = demoFallback
        // Recompute live position from the last snapshot's anchor for accurate, smooth
        // sync of the slider and lyrics (no naive drift).
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, !self.usingDemo, self.isPlaying, var np = self.nowPlaying else { return }
            let pos = self.baseElapsed + Date().timeIntervalSince(self.anchor)
            np.elapsed = np.duration > 0 ? min(max(pos, 0), np.duration) : max(pos, 0)
            self.nowPlaying = np
        }
        guard locateAdapter() else { startDemoIfNeeded(); return }
        launchStream()
        // If the stream produces nothing within 2.5s, show the demo meanwhile.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, self.nowPlaying == nil else { return }
            self.startDemoIfNeeded()
        }
    }

    private func locateAdapter() -> Bool {
        let base = Bundle.main.resourceURL
        let candidates = [base?.appendingPathComponent("Adapter"), base]
        for dir in candidates.compactMap({ $0 }) {
            let pl = dir.appendingPathComponent("mediaremote-adapter.pl")
            let fw = dir.appendingPathComponent("MediaRemoteAdapter.framework")
            if FileManager.default.fileExists(atPath: pl.path),
               FileManager.default.fileExists(atPath: fw.path) {
                plURL = pl; frameworkURL = fw; return true
            }
        }
        return false
    }

    // MARK: Streaming

    private func launchStream() {
        guard let plURL, let frameworkURL else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [plURL.path, frameworkURL.path, "stream", "--no-diff", "--debounce=250"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            DispatchQueue.main.async { self?.consume(chunk) }
        }
        do { try proc.run(); process = proc } catch { /* fall back to demo */ }
    }

    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<nl]
            buffer.removeSubrange(...nl)
            if !line.isEmpty { parse(Data(line)) }
        }
    }

    private func parse(_ data: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        // stream wraps the snapshot in "payload"; null payload => nothing playing.
        let payload = root["payload"] as? [String: Any] ?? root
        guard let title = payload["title"] as? String, !title.isEmpty else {
            // Transient gap (e.g. during a track change) or truly stopped. Hold the
            // current track briefly so the UI doesn't flash an empty/branding state;
            // clear only if it stays empty.
            guard !usingDemo else { return }
            emptyWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.usingDemo else { return }
                self.nowPlaying = nil; self.isPlaying = false
            }
            emptyWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
            return
        }
        emptyWork?.cancel()
        stopDemo()
        let artist = payload["artist"] as? String ?? ""
        let album = payload["album"] as? String ?? ""
        let duration = (payload["duration"] as? NSNumber)?.doubleValue ?? 0
        let elapsed = (payload["elapsedTime"] as? NSNumber)?.doubleValue ?? 0
        let rate = (payload["playbackRate"] as? NSNumber)?.doubleValue ?? 1
        let playingFlag = (payload["playing"] as? NSNumber)?.boolValue
        let playing = playingFlag ?? (rate > 0)
        var art: NSImage?
        if let b64 = payload["artworkData"] as? String, let d = Data(base64Encoded: b64) {
            art = NSImage(data: d)
        }

        // Anchor to the snapshot timestamp so elapsed reflects the true position now.
        baseElapsed = elapsed
        if let ts = payload["timestamp"] as? String, let d = Self.isoFormatter.date(from: ts) {
            anchor = d
        } else {
            anchor = Date()
        }
        let live = playing ? elapsed + Date().timeIntervalSince(anchor) : elapsed
        let pos = duration > 0 ? min(max(live, 0), duration) : max(live, 0)

        nowPlaying = NowPlaying(title: title, artist: artist, album: album,
                                artwork: art, duration: duration, elapsed: pos)
        isPlaying = playing
    }

    // MARK: Commands (short-lived perl invocations)

    private func send(_ commandID: Int) {
        guard let plURL, let frameworkURL else {
            if usingDemo, commandID == 2 { isPlaying.toggle() }
            return
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [plURL.path, frameworkURL.path, "send", String(commandID)]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
    }

    func playPause() { usingDemo ? isPlaying.toggle() : send(2) }   // kMRATogglePlayPause
    func next()      { if usingDemo { resetDemoElapsed() } else { send(4) } }
    func previous()  { if !usingDemo { send(5) } }

    // MARK: Demo fallback

    private func startDemoIfNeeded() {
        guard demoFallback, !usingDemo, nowPlaying == nil else { return }
        usingDemo = true
        isPlaying = true
        nowPlaying = NowPlaying(title: "Midnight Drive", artist: "HaloNotch (demo)",
                                album: "Neon Nights", artwork: Self.demoArtwork(),
                                duration: 214, elapsed: 0)
        demoTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.usingDemo, self.isPlaying, var np = self.nowPlaying else { return }
            np.elapsed = np.elapsed + 1 > np.duration ? 0 : np.elapsed + 1
            self.nowPlaying = np
        }
    }

    private func resetDemoElapsed() {
        guard var np = nowPlaying else { return }
        np.elapsed = 0; nowPlaying = np
    }

    private func stopDemo() {
        guard usingDemo else { return }
        usingDemo = false
        demoTimer?.invalidate(); demoTimer = nil
    }

    private static func demoArtwork() -> NSImage {
        let size = NSSize(width: 256, height: 256)
        let img = NSImage(size: size)
        img.lockFocus()
        NSGradient(colors: [.systemIndigo, .systemPink, .systemOrange])?
            .draw(in: NSRect(origin: .zero, size: size), angle: 45)
        img.unlockFocus()
        return img
    }
}
