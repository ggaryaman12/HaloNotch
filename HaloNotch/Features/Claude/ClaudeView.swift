import SwiftUI

/// Small heartbeat indicator shown in the idle notch while Claude is thinking/working:
/// a Claude glyph that pulses with an expanding ring.
struct ClaudePulse: View {
    @State private var beat = false
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .scaleEffect(beat ? 1.7 : 0.7)
                .opacity(beat ? 0 : 0.85)
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(beat ? 1.18 : 0.92)
                .shadow(color: .white.opacity(0.5), radius: beat ? 4 : 1)
        }
        .frame(width: 18, height: 14)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { beat = true }
        }
    }
}

/// Collects answer-chip frames (window-local, top-left) keyed by option index, so the
/// AppKit mouse monitor in NotchWindow can hit-test them.
struct AnswerRectKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// A small pill that drops just BELOW the physical notch while Claude is thinking or
/// waiting — so the activity is actually visible (the closed notch band itself is hidden
/// behind the hardware notch). Shows the heartbeat glyph plus a short status word.
struct ClaudePeek: View {
    @Environment(AppEnvironment.self) private var env
    private var c: ClaudeMonitor { env.claude }

    var body: some View {
        HStack(spacing: 6) {
            ClaudePulse()
            Text(label)
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(.black)
                .overlay(Capsule().stroke(Theme.Palette.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
        )
        .fixedSize()
    }

    private var label: String {
        switch c.status {
        case .waiting: return c.pendingQuestion != nil ? "Needs you" : "Waiting…"
        case .working: return c.currentAction.isEmpty ? "Thinking…" : "Working…"
        case .done:    return "Done"
        case .idle:    return "Claude"
        }
    }
}

/// Claude Code activity inside the notch: status, live thinking, current action, and
/// a pending question with answer buttons (typed into the focused terminal).
struct ClaudeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var copiedHint = false

    private var c: ClaudeMonitor { env.claude }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                statusDot
                Text(statusText).font(Theme.Typography.caption.weight(.semibold))
                Spacer()
                if !c.sessionTitle.isEmpty {
                    Text(c.sessionTitle).font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary).lineLimit(1)
                }
            }

            if let q = c.pendingQuestion {
                Text(q.text).font(Theme.Typography.body.weight(.medium))
                    .foregroundStyle(.white).lineLimit(3)
                answerButtons(q)
            } else if c.status == .waiting && !c.attentionMessage.isEmpty {
                Text(c.attentionMessage).font(Theme.Typography.body.weight(.medium))
                    .foregroundStyle(.white).lineLimit(3)
                Text("Answer in your \(c.source == .editor ? "editor" : "terminal")")
                    .font(Theme.Typography.caption).foregroundStyle(Theme.Palette.textSecondary)
            } else {
                if !c.currentAction.isEmpty {
                    Label(c.currentAction, systemImage: "gearshape")
                        .font(Theme.Typography.caption).foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
                Text(thinkingText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if copiedHint {
                Text("Copied — paste into VS Code").font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.good)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func answerButtons(_ q: ClaudeMonitor.Question) -> some View {
        let opts = q.options.isEmpty ? ["Yes", "No"] : q.options
        // These are rendered as plain styled chips, not SwiftUI Buttons: the click is
        // hit-tested by NotchWindow's global mouse monitor (so it fires even when the
        // non-activating panel isn't key). We just publish each chip's frame here.
        HStack(spacing: 6) {
            ForEach(Array(opts.enumerated()), id: \.offset) { i, opt in
                Text(opt).font(Theme.Typography.caption.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.16)))
                    .background(GeometryReader { g in
                        Color.clear.preference(key: AnswerRectKey.self,
                                               value: [i: g.frame(in: .global)])
                    })
            }
        }
        .onPreferenceChange(AnswerRectKey.self) { rects in
            env.notch.answerRects = rects
        }
    }

    private var thinkingText: String {
        if !c.latestThinking.isEmpty { return c.latestThinking }
        if c.status == .idle { return "No active Claude session" }
        return c.currentAction.isEmpty ? "Working…" : "Thinking…"
    }

    private var statusText: String {
        switch c.status {
        case .idle: return "Idle"
        case .working: return "Working…"
        case .waiting: return "Needs you"
        case .done: return "Done"
        }
    }

    private var statusDot: some View {
        Circle().fill(statusColor).frame(width: 7, height: 7)
    }

    private var statusColor: Color {
        switch c.status {
        case .idle: return .gray
        case .working: return .blue
        case .waiting: return .yellow
        case .done: return Theme.Palette.good
        }
    }
}
