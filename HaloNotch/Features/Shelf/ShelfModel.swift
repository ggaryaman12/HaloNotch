import AppKit
import Observation

/// A file parked in the notch shelf.
struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
    static func == (l: ShelfItem, r: ShelfItem) -> Bool { l.url == r.url }
}

/// Holds dropped files and exposes quick actions (open / reveal / AirDrop).
@Observable
final class ShelfModel {
    private(set) var items: [ShelfItem] = []

    func add(urls: [URL]) {
        for url in urls where !items.contains(where: { $0.url == url }) {
            items.append(ShelfItem(url: url))
        }
    }

    func remove(_ item: ShelfItem) { items.removeAll { $0.id == item.id } }
    func clear() { items.removeAll() }

    // MARK: Actions

    func open(_ item: ShelfItem) { NSWorkspace.shared.open(item.url) }

    func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func airDrop(_ item: ShelfItem) {
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: [item.url])
    }
}
