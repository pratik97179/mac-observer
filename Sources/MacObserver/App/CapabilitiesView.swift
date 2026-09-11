import SwiftUI
import MacObserverDomain

struct CapabilitiesView: View {
    @Bindable var store: OverviewStore
    @State private var selectedID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                VStack(alignment: .leading, spacing: Theme.Space.compact) {
                    Text("Capabilities")
                        .font(Theme.Typography.pageTitle)
                    Text("Standard collectors stay on this Mac. Turning one off stops future samples from that source.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Color.secondary)
                        .frame(maxWidth: 640, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: Theme.Space.compact) {
                    ForEach(store.capabilities) { capability in
                        capabilityRow(capability)
                    }
                }
                .padding(Theme.Space.standard)
                    .glass(.elevated, radius: Theme.Radius.secondary)

                if let selected, let capability = store.capabilities.first(where: { $0.id == selected }) {
                    detail(capability)
                        .padding(Theme.Space.standard)
                        .glass(.elevated, radius: Theme.Radius.secondary)
                        .transition(Motion.fadeUp)
                }
            }
            .frame(maxWidth: 880, alignment: .leading)
            .animation(Motion.state, value: selectedID)
            .instrumentContent()
        }
        .instrumentScreen()
    }

    private var selected: String? { selectedID }

    private func capabilityRow(_ capability: CapabilityDescriptor) -> some View {
        let enabled = store.isCapabilityEnabled(capability.id)
        let state = store.capabilityState(capability.id)
        let selected = selectedID == capability.id
        return Button {
            selectedID = capability.id
        } label: {
            HStack(alignment: .center, spacing: Theme.Space.control) {
                Circle()
                    .fill(dotColor(enabled: enabled, state: state))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: Theme.Space.micro) {
                    Text(capability.title)
                        .font(Theme.Typography.section)
                        .foregroundStyle(Theme.Color.text)
                    Text(accessLabel(capability.accessLevel))
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(Theme.Color.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: enabledBinding(capability.id))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Theme.Color.accent)
            }
            .padding(Theme.Space.control)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.item, style: .continuous)
                    .fill(selected ? Theme.Color.accent.opacity(0.10) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
    }

    private func detail(_ capability: CapabilityDescriptor) -> some View {
        let enabled = store.isCapabilityEnabled(capability.id)
        let state = store.capabilityState(capability.id)
        return VStack(alignment: .leading, spacing: Theme.Space.standard) {
            Text(capability.title)
                .font(Theme.Typography.section)
            labeled("Provides", capability.summary)
            labeled("Domains", domainLabel(capability.domains))
            labeled("Why this access", accessReason(capability.accessLevel))
            labeled("How to enable", enableCopy(enabled: enabled, state: state, level: capability.accessLevel))
            Text(state)
                .font(Theme.Typography.metadata)
                .foregroundStyle(enabled ? Theme.Color.success : Theme.Color.tertiary)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            Text(title.uppercased())
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Color.tertiary)
            Text(value)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.secondary)
        }
    }

    private func enabledBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { store.isCapabilityEnabled(id) },
            set: { store.setCapabilityEnabled(id, enabled: $0) }
        )
    }

    private func accessLabel(_ level: AccessLevel) -> String {
        switch level {
        case .standard: "Standard access"
        case .privileged: "Privileged. Requires extra authorization."
        case .external: "External network request"
        }
    }

    private func accessReason(_ level: AccessLevel) -> String {
        switch level {
        case .standard:
            "Reads host counters that macOS already exposes to a local process."
        case .privileged:
            "Needs extra authorization because the source is not available with standard process rights."
        case .external:
            "Would leave this Mac. That class of source is not shipped."
        }
    }

    private func enableCopy(enabled: Bool, state: String, level: AccessLevel) -> String {
        if enabled {
            return "This collector is on. Samples stay in the local store."
        }
        if state.lowercased().contains("denied") {
            return "Grant the required permission in System Settings, then turn this collector on."
        }
        if level == .privileged {
            return "Authorize the extra right for this Mac, then turn the switch on."
        }
        return "Turn the switch on to start collecting this source."
    }

    private func dotColor(enabled: Bool, state: String) -> Color {
        if !enabled { return Theme.Color.disabled }
        if state.lowercased().contains("denied") { return Theme.Color.warning }
        if state == "Collecting" { return Theme.Color.success }
        return Theme.Color.tertiary
    }

    private func domainLabel(_ domains: [TelemetryDomain]) -> String {
        domains.map(\.rawValue).joined(separator: ", ")
    }
}
