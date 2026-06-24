import SwiftUI

/// Open-notch card: a tab bar plus the selected module. 3D cross-transitions
/// between tabs give depth without heavy GPU cost.
struct ExpandedView: View {
    @Environment(AppEnvironment.self) private var env

    private var tabs: [NotchViewModel.Tab] {
        var t: [NotchViewModel.Tab] = []
        if env.preferences.mediaEnabled { t.append(.media) }
        if env.preferences.calendarEnabled { t.append(.calendar) }
        if env.preferences.shelfEnabled { t.append(.shelf) }
        t.append(.claude)
        return t.isEmpty ? [.media] : t
    }

    var body: some View {
        VStack(spacing: 8) {
            TabBar(tabs: tabs,
                   selection: env.notch.selectedTab,
                   onSelect: { tab in withAnimation(Motion.tab) { env.notch.select(tab) } })

            ZStack {
                switch env.notch.selectedTab {
                case .media:    MediaView()
                case .calendar: CalendarView()
                case .shelf:    ShelfView()
                case .claude:   ClaudeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .modifier(active: FlipModifier(angle: 35, anchor: .bottom),
                                     identity: FlipModifier(angle: 0, anchor: .bottom)),
                removal: .opacity))
            .id(env.notch.selectedTab)
        }
        .padding(.top, 6)
        .foregroundStyle(.white)
    }
}

/// Segmented tab control with a sliding accent pill.
private struct TabBar: View {
    let tabs: [NotchViewModel.Tab]
    let selection: NotchViewModel.Tab
    let onSelect: (NotchViewModel.Tab) -> Void
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                Button { onSelect(tab) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                        if selection == tab { Text(tab.title).font(Theme.Typography.caption) }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background {
                        if selection == tab {
                            Capsule().fill(.white.opacity(0.14))
                                .matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == tab ? .white : Theme.Palette.textSecondary)
            }
        }
        .font(.caption)
    }
}

/// A 3D flip used for tab content transitions.
private struct FlipModifier: ViewModifier, Animatable {
    var angle: Double
    var anchor: UnitPoint
    var animatableData: Double {
        get { angle } set { angle = newValue }
    }
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: anchor, perspective: 0.5)
            .opacity(1 - abs(angle) / 90)
    }
}
