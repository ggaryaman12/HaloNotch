import Foundation
import Observation

/// Fetches time-synced lyrics from LRCLIB (free, no auth) and exposes the current
/// line for a given playback position. Falls back to plain (unsynced) lyrics.
@Observable
final class LyricsService {
    struct Line: Identifiable, Equatable {
        let id = UUID()
        let time: TimeInterval
        let text: String
    }

    private(set) var lines: [Line] = []
    private(set) var plain: String?
    private(set) var loading = false
    private var fetchedKey = ""

    /// Load lyrics for a track (no-op if already loaded for this track).
    func load(artist: String, title: String, album: String, duration: TimeInterval) {
        let key = "\(artist)|\(title)"
        guard key != fetchedKey, !title.isEmpty else { return }
        fetchedKey = key
        lines = []; plain = nil; loading = true

        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        comps.queryItems = [
            .init(name: "artist_name", value: artist),
            .init(name: "track_name", value: title),
            .init(name: "album_name", value: album),
            .init(name: "duration", value: String(Int(duration))),
        ]
        guard let url = comps.url else { loading = false; return }
        fetch(url) { [weak self] parsed, plainText in
            guard let self else { return }
            if parsed.isEmpty {
                // Exact match failed — fall back to fuzzy search.
                self.search(artist: artist, title: title, fallbackPlain: plainText)
            } else {
                self.lines = parsed; self.plain = plainText; self.loading = false
            }
        }
    }

    /// Fuzzy fallback: LRCLIB /api/search returns candidates; take the first synced hit.
    private func search(artist: String, title: String, fallbackPlain: String?) {
        var comps = URLComponents(string: "https://lrclib.net/api/search")!
        comps.queryItems = [.init(name: "q", value: "\(artist) \(title)")]
        guard let url = comps.url else { finish([], fallbackPlain); return }
        var req = URLRequest(url: url)
        req.setValue("HaloNotch/0.1 (macOS notch app)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self else { return }
            var parsed: [Line] = []
            var plainText = fallbackPlain
            if let data, let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in arr {
                    if let synced = item["syncedLyrics"] as? String, !synced.isEmpty {
                        parsed = Self.parseLRC(synced); break
                    }
                    if plainText == nil, let p = item["plainLyrics"] as? String { plainText = p }
                }
            }
            self.finish(parsed, plainText)
        }.resume()
    }

    private func fetch(_ url: URL, _ done: @escaping ([Line], String?) -> Void) {
        var req = URLRequest(url: url)
        req.setValue("HaloNotch/0.1 (macOS notch app)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            var parsed: [Line] = []
            var plainText: String?
            if let data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let synced = obj["syncedLyrics"] as? String { parsed = Self.parseLRC(synced) }
                plainText = obj["plainLyrics"] as? String
            }
            DispatchQueue.main.async { done(parsed, plainText) }
        }.resume()
    }

    private func finish(_ parsed: [Line], _ plainText: String?) {
        DispatchQueue.main.async {
            self.lines = parsed; self.plain = plainText; self.loading = false
        }
    }

    /// Index of the line that should be highlighted at time `t`.
    func currentIndex(at t: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        var idx: Int?
        for (i, l) in lines.enumerated() {
            if l.time <= t + 0.2 { idx = i } else { break }
        }
        return idx
    }

    static func parseLRC(_ s: String) -> [Line] {
        var out: [Line] = []
        let pattern = #"\[(\d+):(\d+)(?:[.:](\d+))?\]"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        for raw in s.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let ns = line as NSString
            let matches = re.matches(in: line, range: NSRange(location: 0, length: ns.length))
            guard !matches.isEmpty else { continue }
            let text = re.stringByReplacingMatches(
                in: line, range: NSRange(location: 0, length: ns.length), withTemplate: "")
                .trimmingCharacters(in: .whitespaces)
            for m in matches {
                let mm = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let ss = Double(ns.substring(with: m.range(at: 2))) ?? 0
                var frac = 0.0
                if m.range(at: 3).location != NSNotFound {
                    frac = Double("0." + ns.substring(with: m.range(at: 3))) ?? 0
                }
                if !text.isEmpty { out.append(Line(time: mm * 60 + ss + frac, text: text)) }
            }
        }
        return out.sorted { $0.time < $1.time }
    }
}
