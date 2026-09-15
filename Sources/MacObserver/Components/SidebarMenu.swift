import SwiftUI
import AppKit
import MacObserverCollectors
import MacObserverDomain

enum SidebarMonitorState {
    case live
    case paused
    case unavailable

    static func from(snapshot: LiveSnapshot) -> SidebarMonitorState {
        let blocked = snapshot.availability.contains { id, state in
            guard id.hasPrefix("standard.") else { return false }
            switch state {
            case .unavailable, .denied: return true
            default: return false
            }
        }
        return blocked ? .unavailable : .live
    }
}

struct AppSidebar: View {
    @Binding var selection: Profile
    var monitoringSince: Date
    var monitorState: SidebarMonitorState = .live
    var onSelect: (Profile) -> Void = { _ in }
    @Environment(\.designMetrics) private var metrics
    @FocusState private var focusedProfile: Profile?

    var body: some View {
        SidebarIsland {
            ViewThatFits(in: .vertical) {
                islandContent(scrolls: false)
                islandContent(scrolls: true)
            }
        }
        .focusSection()
        .onMoveCommand(perform: moveFocus)
        .zIndex(1)
    }

    @ViewBuilder
    private func islandContent(scrolls: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TrafficLightArea()

            SidebarBrand(compact: metrics.sidebarCompact)
                .padding(.bottom, metrics.spacing.md)

            if scrolls {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: metrics.spacing.xl) {
                        primaryNavigation
                        secondaryNavigation
                    }
                }
                .scrollClipDisabled()
            } else {
                primaryNavigation
                Spacer(minLength: metrics.spacing.xl)
                secondaryNavigation
            }

            SidebarMonitoringStatus(
                since: monitoringSince,
                state: monitorState,
                compact: metrics.sidebarCompact
            )
            .padding(.top, metrics.spacing.md)
        }
        .padding(.horizontal, metrics.spacing.md)
        .padding(.bottom, metrics.spacing.md)
    }

    private var primaryNavigation: some View {
        SidebarNavigation(
            items: Profile.views,
            selection: $selection,
            focusedProfile: $focusedProfile,
            compact: metrics.sidebarCompact,
            onSelect: select
        )
    }

    private var secondaryNavigation: some View {
        SidebarGroup(
            title: "System",
            items: Profile.system,
            selection: $selection,
            focusedProfile: $focusedProfile,
            compact: metrics.sidebarCompact,
            onSelect: select
        )
    }

    private func select(_ profile: Profile) {
        if isMouseDrivenEvent {
            focusedProfile = nil
        } else {
            focusedProfile = profile
        }
        onSelect(profile)
        selection = profile
    }

    private func moveFocus(_ direction: MoveCommandDirection) {
        let items = Profile.views + Profile.system
        guard !items.isEmpty else { return }
        let current = focusedProfile ?? selection
        guard let index = items.firstIndex(of: current) else {
            focusedProfile = items.first
            return
        }
        switch direction {
        case .up:
            focusedProfile = items[max(items.startIndex, index - 1)]
        case .down:
            focusedProfile = items[min(items.index(before: items.endIndex), index + 1)]
        default:
            break
        }
    }

    private var isMouseDrivenEvent: Bool {
        guard let event = NSApp.currentEvent else { return false }
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
            return true
        default:
            return false
        }
    }
}

struct SidebarIsland<Content: View>: View {
    @Environment(\.designMetrics) private var metrics
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            SidebarIslandSurface(cornerRadius: metrics.radius.window/2)
            content
        }
        .frame(width: metrics.sidebarWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.leading, metrics.spacing.sm/2)
        .padding(.vertical, metrics.spacing.sm/2)
    }
}

enum SidebarMaterialDebugStage: Int, CaseIterable, Identifiable {
    case none = 0
    case material = 1
    case tint = 2
    case edge = 3
    case production = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "0 No material"
        case .material: "1 Material only"
        case .tint: "2 Material + tint"
        case .edge: "3 Material + tint + edge"
        case .production: "4 Production"
        }
    }
}

struct SidebarIslandSurface: View {
    var cornerRadius: CGFloat = Theme.Radius.window
    #if DEBUG
    @AppStorage("MacObserver.sidebarMaterialDebugStage") private var debugStageRaw = SidebarMaterialDebugStage.production.rawValue
    #endif

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let stage = debugStage
        ZStack {
            if stage != .none {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(stage == .material ? 0.55 : Theme.Sidebar.materialOpacity)
            }
            if stage == .tint || stage == .edge || stage == .production {
                Theme.Sidebar.materialTint
            }
        }
        .clipShape(shape)
        .overlay {
            if stage == .edge || stage == .production {
                shape.stroke(Color.white.opacity(Theme.Sidebar.edgeOpacity), lineWidth: 1)
            }
        }
        .shadow(
            color: stage == .production ? Color.black.opacity(Theme.Sidebar.islandShadow) : .clear,
            radius: Theme.Sidebar.islandShadowRadius,
            y: Theme.Sidebar.islandShadowY
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var debugStage: SidebarMaterialDebugStage {
        #if DEBUG
        SidebarMaterialDebugStage(rawValue: debugStageRaw) ?? .production
        #else
        .production
        #endif
    }
}

#if DEBUG
struct SidebarMaterialDebugCommands: Commands {
    @AppStorage("MacObserver.sidebarMaterialDebugStage") private var debugStageRaw = SidebarMaterialDebugStage.production.rawValue

    var body: some Commands {
        CommandMenu("Sidebar Material") {
            ForEach(SidebarMaterialDebugStage.allCases) { stage in
                Button(stage.title) {
                    debugStageRaw = stage.rawValue
                }
            }
        }
    }
}
#endif

struct TrafficLightArea: View {
    @Environment(\.designMetrics) private var metrics

    var body: some View {
        Color.clear
            .frame(height: max(Theme.Space.sidebarTop - metrics.spacing.sm, metrics.spacing.xl))
            .accessibilityHidden(true)
    }
}

struct SidebarBrand: View {
    var compact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Sidebar.itemSpacing) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Color.accentMuted)
                .frame(width: Theme.Sidebar.iconSlot, height: Theme.Sidebar.iconSlot)
            if !compact {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mac Observer")
                        .font(Theme.Typography.section)
                        .foregroundStyle(Theme.Color.text)
                        .lineLimit(1)
                    Text("Live cockpit")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Color.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help("Mac Observer")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mac Observer")
    }
}

struct SidebarNavigation: View {
    let items: [Profile]
    @Binding var selection: Profile
    var focusedProfile: FocusState<Profile?>.Binding
    var compact: Bool
    var onSelect: (Profile) -> Void

    var body: some View {
        SidebarGroup(
            items: items,
            selection: $selection,
            focusedProfile: focusedProfile,
            compact: compact,
            onSelect: onSelect
        )
    }
}

struct SidebarGroup: View {
    var title: String?
    let items: [Profile]
    @Binding var selection: Profile
    var focusedProfile: FocusState<Profile?>.Binding
    var compact: Bool
    var onSelect: (Profile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            if let title {
                SidebarGroupLabel(title, compact: compact)
            }
            ForEach(items) { profile in
                SidebarItem(
                    title: profile.rawValue,
                    symbol: profile.symbol,
                    selected: selection == profile,
                    focused: focusedProfile.wrappedValue == profile,
                    compact: compact
                ) {
                    onSelect(profile)
                }
                .focused(focusedProfile, equals: profile)
            }
        }
    }
}

struct SidebarGroupLabel: View {
    let title: String
    var compact: Bool

    init(_ title: String, compact: Bool) {
        self.title = title
        self.compact = compact
    }

    var body: some View {
        if !compact {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Color.tertiary)
                .fixedSize()
                .padding(.bottom, 2)
        }
    }
}

struct SidebarItem: View {
    let title: String
    let symbol: String
    let selected: Bool
    var focused: Bool = false
    var compact: Bool = false
    var tool: Bool = false
    var disabled: Bool = false
    let action: () -> Void
    @Environment(\.designMetrics) private var metrics
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Sidebar.itemSpacing) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: Theme.Sidebar.iconSlot, height: Theme.Sidebar.iconSlot)
                    .foregroundStyle(iconColor)
                if !compact {
                    Text(title)
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(labelColor)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Space.itemHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .focusable(!disabled)
        .focusEffectDisabled()
        .modifier(
            SidebarItemStyle(
                selected: selected,
                hovering: hovering,
                pressed: pressed,
                focused: focused,
                disabled: disabled
            )
        )
        .onHover { hovering = $0 }
        .pressEvents(pressed: $pressed)
        .overlay(alignment: .trailing) {
            if compact && hovering && !disabled {
                SidebarTooltip(title: title)
                    .padding(.leading, metrics.spacing.sm)
                    .offset(x: metrics.spacing.md)
                    .zIndex(20)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(title)
    }

    private var iconColor: Color {
        if disabled { return Theme.Color.disabled }
        if selected { return Theme.Color.accent }
        if hovering || focused { return Theme.Color.accentMuted }
        return Theme.Color.tertiary
    }

    private var labelColor: Color {
        if disabled { return Theme.Color.disabled }
        if selected || hovering || focused { return Theme.Color.text }
        return Theme.Color.secondary
    }
}

struct SidebarToolItem: View {
    let title: String
    let symbol: String
    var selected: Bool = false
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        SidebarItem(title: title, symbol: symbol, selected: selected, compact: compact, tool: true, action: action)
    }
}

struct SidebarItemStyle: ViewModifier {
    var selected: Bool
    var hovering: Bool
    var pressed: Bool
    var focused: Bool
    var disabled: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        content
            .padding(.horizontal, Theme.Space.control)
            .background { fill(shape) }
            .overlay { inner(shape) }
            .overlay {
                if focused && !disabled {
                    shape.strokeBorder(Theme.Color.accent.opacity(Theme.Sidebar.focusOutline), lineWidth: 1)
                }
            }
            .shadow(
                color: selected && !pressed && !disabled ? Color.black.opacity(0.10) : .clear,
                radius: pressed ? 2 : 6,
                x: 0,
                y: pressed ? 0 : 1
            )
            .overlay {
                if selected && pressed {
                    shape.fill(Color.black.opacity(0.04))
                }
            }
            .offset(y: pressed && !disabled ? 1 : 0)
            .opacity(disabled ? 0.55 : 1)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: Theme.Motion.hover), value: hovering)
            .animation(.easeOut(duration: Theme.Motion.micro), value: pressed)
            .animation(.easeInOut(duration: Theme.Motion.state), value: selected)
            .animation(.easeOut(duration: Theme.Motion.hover), value: focused)
    }

    @ViewBuilder
    private func fill(_ shape: RoundedRectangle) -> some View {
        if selected {
            shape.fill(Color.white.opacity(pressed ? 0.03 : Theme.Sidebar.selectedFill))
        } else if pressed {
            shape.fill(Color.white.opacity(0.02))
        } else if hovering && !disabled {
            shape.fill(Color.white.opacity(Theme.Sidebar.hoverFill))
        }
    }

    @ViewBuilder
    private func inner(_ shape: RoundedRectangle) -> some View {
        if selected {
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(pressed ? 0.012 : 0.03),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.48)
                )
            )
        }
    }
}

struct SidebarTooltip: View {
    let title: String
    var shortcut: String?

    var body: some View {
        HStack(spacing: Theme.Space.compact) {
            Text(title)
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Color.text)
            if let shortcut {
                Text(shortcut)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
            }
        }
        .padding(.horizontal, Theme.Space.control)
        .padding(.vertical, Theme.Space.compact)
        .glass(.floating, radius: Theme.Radius.control)
        .fixedSize()
    }
}

struct SidebarMonitoringStatus: View {
    let since: Date
    var state: SidebarMonitorState
    var compact: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: Theme.Space.compact) {
            Circle()
                .fill(dot)
                .frame(width: 7, height: 7)
                .opacity(pulse ? 0.35 : 1)
            if !compact {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.secondary)
                    if state == .live {
                        Text("Since \(since.formatted(date: .omitted, time: .shortened))")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Color.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .help(help)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(help)
        .onChange(of: state) { _, newState in
            guard newState != .live else { return }
            withAnimation(.easeOut(duration: Theme.Motion.micro)) { pulse = true }
            withAnimation(.easeOut(duration: Theme.Motion.state).delay(Theme.Motion.micro)) { pulse = false }
        }
    }

    private var dot: Color {
        switch state {
        case .live: Theme.Color.success
        case .paused: Theme.Color.warning
        case .unavailable: Theme.Color.critical
        }
    }

    private var title: String {
        switch state {
        case .live: "Monitoring"
        case .paused: "Paused"
        case .unavailable: "Monitoring unavailable"
        }
    }

    private var help: String {
        switch state {
        case .live: "Monitoring since \(since.formatted(date: .omitted, time: .shortened))"
        case .paused: "Paused"
        case .unavailable: "Monitoring unavailable"
        }
    }
}

private extension View {
    func pressEvents(pressed: Binding<Bool>) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed.wrappedValue {
                        withAnimation(.easeOut(duration: Theme.Motion.micro)) { pressed.wrappedValue = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: Theme.Motion.micro)) { pressed.wrappedValue = false }
                }
        )
    }
}
