import Foundation
import Observation

/// Watches Claude Code sessions (terminal AND the VS Code extension both write the
/// same JSONL transcripts under ~/.claude/projects). Surfaces the live thinking,
/// current action, status, and any pending question. A Claude Code Notification/Stop
/// hook writes ~/.claude/halonotch/signal.json, which we watch to react instantly.
@Observable
final class ClaudeMonitor {
    enum Status: Equatable { case idle, working, waiting, done }
    enum Source: Equatable { case terminal, editor }

    struct Question: Equatable {
        var text: String
        var options: [String]   // empty => free-form / yes-no
        var isPermission = false // a tool-permission prompt (Approve=Enter / Reject=Esc)
    }

    private(set) var status: Status = .idle
    private(set) var latestThinking: String = ""
    private(set) var lastThinking: String = ""
    private(set) var currentAction: String = ""        // e.g. "Running Bash", "Editing file"
    private(set) var sessionTitle: String = ""
    private(set) var pendingQuestion: Question?
    private(set) var attentionMessage: String = ""
    /// Which app owns the active session, so answers can be routed there.
    private(set) var source: Source = .terminal

    /// Called when Claude needs attention (pop the notch out). Set by AppEnvironment.
    var onAttention: (() -> Void)?

    private let projectsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")
    private let signalURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/halonotch/signal.json")

    private var pollTimer: Timer?
    private var lastSignalDate: Date?
    private var activeSession: URL?
    private var waitingHold: Date = .distantPast   // keep "waiting" sticky after a signal
    private var signalQuestion: Question?          // question captured from a PreToolUse signal, before the transcript flushes
    private var stoppedAt: Date = .distantPast     // when the last Stop signal fired
    private var hasActivitySinceStop = false       // transcript modified after that Stop?

    func start() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    private func tick() {
        checkSignal()
        guard let session = newestTranscript() else {
            debugLog("tick: NO active transcript (all idle >10m?)")
            return
        }
        activeSession = session
        sessionTitle = prettyTitle(for: session)
        // Did the transcript change after the last Stop? If so, Claude resumed and we can
        // let activity flip status back to working; otherwise the Stop stays authoritative.
        let modDate = (try? session.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
        hasActivitySinceStop = modDate > stoppedAt.addingTimeInterval(0.5)
        parse(readTail(session))
        debugLog("tick status=\(status) action=\"\(currentAction)\" src=\(source) q=\(pendingQuestion?.text ?? "nil") file=\(session.lastPathComponent)")
    }

    private var lastDebug = ""
    private func debugLog(_ s: String) {
        guard ProcessInfo.processInfo.environment["HALO_DEBUG"] != nil, s != lastDebug else { return }
        lastDebug = s
        FileHandle.standardError.write(("claudeMonitor: " + s + "\n").data(using: .utf8)!)
    }

    // MARK: Hook signal

    private func checkSignal() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: signalURL.path),
              let mod = attrs[.modificationDate] as? Date else { return }
        if let last = lastSignalDate, mod <= last { return }
        let isFirst = (lastSignalDate == nil)
        lastSignalDate = mod
        guard !isFirst else { return }   // don't pop on launch for a stale signal

        if let data = try? Data(contentsOf: signalURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let event = (obj["hook_event_name"] as? String) ?? ""
            attentionMessage = (obj["message"] as? String) ?? "Claude needs your attention"
            if event == "Stop" {
                status = .done
                waitingHold = .distantPast
                signalQuestion = nil
                stoppedAt = mod
                hasActivitySinceStop = false
            } else {
                // A PreToolUse signal for AskUserQuestion carries the question + options
                // in tool_input — capture them so buttons show instantly, before the
                // transcript flushes the tool_use line.
                if let input = obj["tool_input"] as? [String: Any],
                   let qs = input["questions"] as? [[String: Any]], let first = qs.first {
                    let text = first["question"] as? String ?? "Claude asked a question"
                    let opts = (first["options"] as? [[String: Any]])?.compactMap { $0["label"] as? String } ?? []
                    signalQuestion = Question(text: text, options: opts)
                } else if event == "Notification" {
                    // A Notification (e.g. a tool-permission request) has no per-option
                    // payload — offer Approve / Reject straight from the signal so it's
                    // answerable from the notch without waiting on the transcript.
                    signalQuestion = Question(text: attentionMessage, options: ["Approve", "Reject"], isPermission: true)
                }
                status = .waiting
                waitingHold = Date().addingTimeInterval(45)
                onAttention?()
            }
        } else {
            status = .waiting
            waitingHold = Date().addingTimeInterval(45)
            onAttention?()
        }
    }

    // MARK: Transcript discovery

    private func newestTranscript() -> URL? {
        guard let en = FileManager.default.enumerator(
            at: projectsDir, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return nil }
        var newest: URL?; var newestDate = Date.distantPast
        for case let url as URL in en where url.pathExtension == "jsonl" {
            let d = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if d > newestDate { newestDate = d; newest = url }
        }
        // Ignore sessions idle for >10 min.
        return newestDate.timeIntervalSinceNow > -600 ? newest : nil
    }

    private func prettyTitle(for url: URL) -> String {
        // Folder name is the encoded cwd, e.g. "-Users-aryamangupta-HaloNotch".
        let folder = url.deletingLastPathComponent().lastPathComponent
        return folder.split(separator: "-").last.map(String.init) ?? "Claude"
    }

    private func readTail(_ url: URL, maxBytes: Int = 700_000) -> [String] {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? fh.close() }
        let size = (try? fh.seekToEnd()) ?? 0
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? fh.seek(toOffset: start)
        let data = (try? fh.readToEnd()) ?? Data()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n").map(String.init)
    }

    // MARK: Parsing

    private func parse(_ lines: [String]) {
        var thinkings: [String] = []
        var lastTool = ""
        var question: Question?
        var lastType = ""
        var lastToolId = ""
        var askId = ""
        var resultIds = Set<String>()
        var entrypoint = ""

        for line in lines {
            guard let d = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
            let type = obj["type"] as? String ?? ""
            if let e = obj["entrypoint"] as? String, !e.isEmpty { entrypoint = e }
            if type == "assistant" || type == "user" { lastType = type }

            guard let msg = obj["message"] as? [String: Any],
                  let content = msg["content"] as? [[String: Any]] else { continue }

            if type == "user" {
                // Record which tool_use ids have results (i.e. already ran/answered).
                for block in content where block["type"] as? String == "tool_result" {
                    if let id = block["tool_use_id"] as? String { resultIds.insert(id) }
                }
                continue
            }
            guard type == "assistant" else { continue }

            for block in content {
                switch block["type"] as? String {
                case "thinking":
                    if let t = block["thinking"] as? String, !t.isEmpty { thinkings.append(t) }
                case "tool_use":
                    let name = block["name"] as? String ?? ""
                    let input = block["input"] as? [String: Any]
                    lastTool = friendlyTool(name, input)
                    lastToolId = block["id"] as? String ?? ""
                    if name == "AskUserQuestion" || name == "ask_user_input_v0" {
                        question = extractQuestion(input)
                        askId = block["id"] as? String ?? ""
                    } else {
                        question = nil
                    }
                default: break
                }
            }
        }

        latestThinking = thinkings.last ?? latestThinking
        if thinkings.count >= 2 { lastThinking = thinkings[thinkings.count - 2] }
        currentAction = lastTool
        // "cli" => terminal; anything else (e.g. the VS Code extension) => editor.
        source = (entrypoint.isEmpty || entrypoint == "cli") ? .terminal : .editor

        // The last tool_use is "pending" if nothing answered it yet.
        let pending = !lastToolId.isEmpty && !resultIds.contains(lastToolId) && lastType == "assistant"

        // Drop the signal-captured question only once the transcript shows that very
        // question answered — i.e. it's the most recent tool and now has a result.
        // Guarding on askId == lastToolId avoids an older answered AskUserQuestion still
        // lingering in the tail wiping a freshly-posed one.
        if !askId.isEmpty && askId == lastToolId && resultIds.contains(askId) { signalQuestion = nil }

        if let q = question, pending {
            // Real question from Claude with its real options — always takes priority.
            pendingQuestion = q
            signalQuestion = nil
            if status != .waiting { status = .waiting; onAttention?() }
        } else if let sq = signalQuestion, status == .waiting, Date() < waitingHold {
            // Question arrived via the PreToolUse hook signal but the transcript hasn't
            // flushed the tool_use line yet — show the buttons now.
            pendingQuestion = sq
        } else if status == .waiting && pending {
            // A tool is waiting on your permission — Approve commits the default (Yes),
            // Reject sends Escape, so it works whatever the picker's option layout is.
            pendingQuestion = Question(text: "Allow \(lastTool)?", options: ["Approve", "Reject"], isPermission: true)
        } else {
            // No real question/action we can answer. Don't invent Yes/No buttons; the
            // attentionMessage (if any) is shown as text only.
            pendingQuestion = nil
            if Date() > waitingHold {
                if status == .done && !hasActivitySinceStop {
                    // Claude stopped and the transcript hasn't moved since — stay done so
                    // the "Working…" peek clears instead of being re-asserted by the
                    // lingering last tool_use in the tail.
                    status = .done
                } else {
                    status = currentAction.isEmpty ? .idle : .working
                }
            }
        }
    }

    private func friendlyTool(_ name: String, _ input: [String: Any]?) -> String {
        switch name {
        case "Bash": return "Running: \((input?["command"] as? String)?.prefix(40) ?? "command")"
        case "Edit", "Write": return "Editing \(((input?["file_path"] as? String) as NSString?)?.lastPathComponent ?? "file")"
        case "Read": return "Reading \(((input?["file_path"] as? String) as NSString?)?.lastPathComponent ?? "file")"
        case "": return ""
        default: return name
        }
    }

    private func extractQuestion(_ input: [String: Any]?) -> Question {
        // AskUserQuestion: { questions: [ { question, options:[{label}] } ] }
        if let qs = input?["questions"] as? [[String: Any]], let first = qs.first {
            let text = first["question"] as? String ?? "Claude asked a question"
            let opts = (first["options"] as? [[String: Any]])?.compactMap { $0["label"] as? String } ?? []
            return Question(text: text, options: opts)
        }
        return Question(text: attentionMessage.isEmpty ? "Claude needs a response" : attentionMessage, options: [])
    }
}
