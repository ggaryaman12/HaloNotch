import AppKit
import UniformTypeIdentifiers

/// Invisible drag-only panel pinned at the notch.
///
/// The notch panel is click-through until opened, and global mouse monitors stay silent
/// during a Finder drag session — so neither can notice a file being dragged toward the
/// notch. This small, always-mouse-enabled panel is the real `NSDraggingDestination`:
/// when a file drag enters the notch zone it opens the shelf and grows to cover the open
/// card, so the file can be dropped anywhere on it. It shrinks back when the drag ends so
/// it never blocks normal clicks on the open card.
final class DropCatcherWindow: NSPanel {
    private let env: AppEnvironment

    init(env: AppEnvironment) {
        self.env = env
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        // Near-invisible (not .clear): a fully transparent panel has no hit region, so the
        // WindowServer routes drags straight past it. A whisper of alpha gives it a real
        // drag target while staying visually imperceptible.
        backgroundColor = NSColor(white: 0, alpha: 0.02)
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let view = DropCatcherView()
        view.env = env
        view.onResize = { [weak self] open in self?.resize(open: open) }
        contentView = view
        resize(open: false)
        if ProcessInfo.processInfo.environment["HALO_DEBUG"] != nil {
            FileHandle.standardError.write("dropCatcher: init frame=\(frame) content=\(view.frame) level=\(level.rawValue)\n".data(using: .utf8)!)
        }
    }

    // Never key/main: like the notch panel, all interaction is monitor- or drag-based, so
    // it must not steal focus from the active app.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Idle = a small zone over the physical notch (padded so "toward the notch" triggers a
    /// little early). Active = the full open-card footprint so a drop lands anywhere on it.
    func resize(open: Bool) {
        let m = ScreenManager.currentMetrics()
        let w: CGFloat, h: CGFloat
        if open {
            let s = env.notch.size(for: .open)
            w = s.width + 60; h = s.height + 40
        } else {
            // Extend well below the notch into normal screen space: the menu-bar strip
            // itself doesn't reliably deliver drags, so the trigger lives just under it.
            w = env.notch.closedSize.width + 80
            h = env.notch.closedSize.height + 110
        }
        setFrame(NSRect(x: m.centerX - w / 2, y: m.topY - h, width: w, height: h), display: false)
    }
}

/// The drag destination. Opens the shelf on entry, stashes dropped files, and asks the
/// window to grow/shrink so the target tracks the open card.
private final class DropCatcherView: NSView {
    weak var env: AppEnvironment?
    var onResize: ((Bool) -> Void)?
    private var active = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        registerForDraggedTypes([
            .fileURL, .URL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func dbg(_ s: String) {
        if ProcessInfo.processInfo.environment["HALO_DEBUG"] != nil {
            FileHandle.standardError.write("dropCatcher: \(s)\n".data(using: .utf8)!)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dbg("ENTERED files=\(hasFiles(sender))")
        guard hasFiles(sender) else { return [] }
        if !active {
            active = true
            DispatchQueue.main.async {
                self.env?.notch.present(.shelf)   // open + select shelf + pin
                self.onResize?(true)              // grow to cover the open card
            }
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        env?.notch.pinnedUntil = Date().addingTimeInterval(20)   // don't auto-close mid-drag
        return hasFiles(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { end() }
    override func draggingEnded(_ sender: NSDraggingInfo) { end() }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { hasFiles(sender) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = readURLs(sender)
        guard !urls.isEmpty else { return false }
        DispatchQueue.main.async {
            self.env?.shelf.add(urls: urls)
            self.env?.notch.present(.shelf)
            self.env?.notch.pinnedUntil = Date().addingTimeInterval(30)
        }
        return true
    }

    /// Shrink back so the idle target sits only over the notch and never eats card clicks.
    private func end() {
        guard active else { return }
        active = false
        DispatchQueue.main.async { self.onResize?(false) }
    }

    private func hasFiles(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self],
                                                options: [.urlReadingFileURLsOnly: true])
    }
    private func readURLs(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                               options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }
}
