import SwiftUI
import UniformTypeIdentifiers

/// Expanded shelf module: a drop target plus file chips. Files can be dragged back
/// out, opened, revealed, or AirDropped. Empty state invites a drop.
struct ShelfView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var targeted = false

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 8)]

    var body: some View {
        ScrollView {
            if env.shelf.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down").font(.title2)
                    Text("Drop files to stash").font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 110)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(env.shelf.items) { item in ChipView(item: item) }
                }
                .padding(.vertical, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .foregroundStyle(targeted ? Color.accentColor : .white.opacity(0.15))
        )
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            handleDrop(providers); return true
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { env.shelf.add(urls: [url]) }
            }
        }
    }
}

/// One file chip: icon, name, hover tilt, context menu, draggable out.
private struct ChipView: View {
    @Environment(AppEnvironment.self) private var env
    let item: ShelfItem
    @State private var hover = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: item.icon).resizable().frame(width: 36, height: 36)
            Text(item.name).font(.system(size: 9)).lineLimit(1).truncationMode(.middle)
        }
        .frame(width: 60, height: 60)
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(hover ? 0.12 : 0.05)))
        .rotation3DEffect(.degrees(hover ? 8 : 0), axis: (x: 1, y: 0.4, z: 0), perspective: 0.6)
        .onHover { isHovering in withAnimation(Motion.hover) { hover = isHovering } }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { env.shelf.open(item) }
            Button("Reveal in Finder") { env.shelf.revealInFinder(item) }
            Button("Share via AirDrop") { env.shelf.airDrop(item) }
            Divider()
            Button("Remove", role: .destructive) { env.shelf.remove(item) }
        }
    }
}
