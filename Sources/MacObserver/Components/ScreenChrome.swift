import SwiftUI
import MacObserverDomain

struct AppSidebar: View {
    @Binding var selection: Profile
    var monitoringSince: Date
    var onSelect: (Profile) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.standard) {
            HStack(spacing: Theme.Space.compact) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                Text("Mac Observer")
                    .font(Theme.Typography.section)
                    .foregroundStyle(Theme.Color.text)
            }
            .padding(.horizontal, Theme.Space.standard)
            .padding(.top, Theme.Space.sidebarTop)

            group(nil, [.overview])
            group(nil, [.performance, .processes, .network, .storage, .power, .events])
            labeled("System", Profile.system)

            Spacer()

            HStack(spacing: Theme.Space.compact) {
                Circle()
                    .fill(Theme.Color.success)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Monitoring")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(Theme.Color.text)
                    Text("Since \(monitoringSince.formatted(date: .omitted, time: .shortened))")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Color.tertiary)
                }
            }
            .padding(.horizontal, Theme.Space.standard)
            .padding(.bottom, Theme.Space.standard)
        }
        .frame(width: Theme.Space.sidebarWidth, alignment: .topLeading)
        .background(Theme.Color.canvas)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.Color.hairline)
                .frame(width: 1)
        }
    }

    private func labeled(_ title: String, _ items: [Profile]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            Text(title)
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Color.tertiary)
                .padding(.horizontal, Theme.Space.component)
            group(nil, items)
        }
    }

    private func group(_ title: String?, _ items: [Profile]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            if let title {
                Text(title)
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Color.tertiary)
                    .padding(.horizontal, Theme.Space.component)
            }
            ForEach(items) { profile in
                SidebarItem(profile: profile, selected: selection == profile) {
                    onSelect(profile)
                    selection = profile
                }
            }
        }
        .padding(.horizontal, Theme.Space.compact)
    }
}

struct SidebarItem: View {
    let profile: Profile
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.control) {
                Image(systemName: profile.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(selected ? Theme.Color.text : Theme.Color.tertiary)
                Text(profile.rawValue)
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(selected ? Theme.Color.text : Theme.Color.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Space.control)
            .frame(height: Theme.Space.itemHeight)
            .background { fill }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.item, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pressEvents(pressed: $pressed)
        .animation(Motion.hover, value: selected || hovering || pressed)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(profile.rawValue)
    }

    @ViewBuilder
    private var fill: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.item, style: .continuous)
        if selected {
            shape.fill(Color.white.opacity(pressed ? 0.10 : 0.12))
        } else if pressed {
            shape.fill(Color.black.opacity(0.16))
        } else if hovering {
            shape.fill(Color.white.opacity(0.04))
        }
    }
}

private extension View {
    func pressEvents(pressed: Binding<Bool>) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed.wrappedValue {
                        withAnimation(Motion.press) { pressed.wrappedValue = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(Motion.press) { pressed.wrappedValue = false }
                }
        )
    }
}

struct AppToolbar: View {
    let onSearch: () -> Void
    var onRefresh: () -> Void = {}

    var body: some View {
        HStack(spacing: Theme.Space.compact) {
            Spacer(minLength: 0)
            Button(action: onSearch) {
                HStack(spacing: Theme.Space.compact) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                    Text("Search…")
                        .font(Theme.Typography.secondary)
                    Spacer(minLength: 0)
                    Text("⌘K")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Color.tertiary)
                }
                .foregroundStyle(Theme.Color.secondary)
                .padding(.horizontal, Theme.Space.control)
                .frame(width: 220, height: 34)
                .glass(.recessed, radius: Theme.Radius.control)
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .keyboardShortcut("k", modifiers: .command)
            .help("Search")
            .accessibilityLabel("Open command palette")

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glass(.recessed, radius: Theme.Radius.control)
            .help("Refresh")
        }
        .padding(.horizontal, Theme.Space.contentX)
        .padding(.trailing, Theme.Space.scrollGutter)
        .padding(.top, Theme.Space.component)
        .padding(.bottom, Theme.Space.standard)
        .background(Theme.Color.canvas)
        .zIndex(1)
    }
}

struct CockpitCard<Content: View>: View {
    var radius: CGFloat = Theme.Radius.secondary
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.Space.surface)
            .cardCell()
            .glass(.elevated, radius: radius)
    }
}
