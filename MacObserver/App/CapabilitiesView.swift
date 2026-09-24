import SwiftUI
import MacObserverDomain
import MacObserverCollectors

struct CapabilitiesView: View {
    @Bindable var store: OverviewStore
    @State private var selectedID: String?
    @State private var pendingEnable: CapabilityDescriptor?
    @State private var pendingDisable: CapabilityDescriptor?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                VStack(alignment: .leading, spacing: Theme.Space.compact) {
                    Text("Capabilities")
                        .font(Theme.Typography.pageTitle)
                    Text("Standard collectors stay on this Mac. Optional sources start off. Turning one off stops future samples from that source.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(AppTheme.secondary)
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
        .onAppear {
            if selectedID == nil {
                selectedID = store.capabilities.first?.id
            }
        }
        .confirmationDialog(
            pendingEnable.map { "Turn on \($0.title)?" } ?? "Turn on this source?",
            isPresented: Binding(
                get: { pendingEnable != nil },
                set: { if !$0 { pendingEnable = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Turn on") {
                if let capability = pendingEnable {
                    store.setCapabilityEnabled(capability.id, enabled: true)
                }
                pendingEnable = nil
            }
            Button("Cancel", role: .cancel) { pendingEnable = nil }
        } message: {
            if let capability = pendingEnable {
                Text(enableDisclosure(capability))
            }
        }
        .confirmationDialog(
            pendingDisable.map { "Turn off \($0.title)?" } ?? "Turn off this source?",
            isPresented: Binding(
                get: { pendingDisable != nil },
                set: { if !$0 { pendingDisable = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Turn off, keep history") {
                if let capability = pendingDisable {
                    store.setCapabilityEnabled(capability.id, enabled: false)
                }
                pendingDisable = nil
            }
            Button("Turn off and delete history", role: .destructive) {
                if let capability = pendingDisable {
                    store.setCapabilityEnabled(capability.id, enabled: false, deleteHistory: true)
                }
                pendingDisable = nil
            }
            Button("Cancel", role: .cancel) { pendingDisable = nil }
        } message: {
            Text("Future samples stop immediately. Delete history only removes rows this source wrote.")
        }
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
                        .foregroundStyle(AppTheme.text)
                    Text(accessLabel(capability.accessLevel))
                        .font(Theme.Typography.metadata)
                        .foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: enabledBinding(capability))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(AppTheme.sage)
            }
            .padding(Theme.Space.control)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.item, style: .continuous)
                    .fill(selected ? AppTheme.sage.opacity(0.10) : Color.clear)
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
            labeled("How it collects", capability.collectionMethod)
            labeled("Domains", domainLabel(capability.domains))
            labeled("Stays on this Mac", capability.remainsLocal ? "Yes. Samples stay in the local store." : "No. A check sends a request off this Mac. The result can be stored locally afterward.")
            labeled("Privacy class", privacyLabel(capability.privacyClass))
            labeled("Why this access", accessReason(capability.accessLevel))
            labeled("How to enable", enableCopy(enabled: enabled, state: state, capability: capability))
            Text(state)
                .font(Theme.Typography.metadata)
                .foregroundStyle(enabled ? AppTheme.success : AppTheme.tertiary)
            if capability.id == ExternalDiagnosticsCollector.capabilityID, enabled {
                Button("Run internet check") {
                    Task { await store.runExternalDiagnostic() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.sage)
            }
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.micro) {
            Text(title.uppercased())
                .font(Theme.Typography.micro)
                .foregroundStyle(AppTheme.tertiary)
            Text(value)
                .font(Theme.Typography.body)
                .foregroundStyle(AppTheme.secondary)
        }
    }

    private func enabledBinding(_ capability: CapabilityDescriptor) -> Binding<Bool> {
        Binding(
            get: { store.isCapabilityEnabled(capability.id) },
            set: { enabled in
                if enabled == store.isCapabilityEnabled(capability.id) { return }
                if enabled {
                    if capability.defaultEnabled {
                        store.setCapabilityEnabled(capability.id, enabled: true)
                    } else {
                        pendingEnable = capability
                    }
                } else {
                    pendingDisable = capability
                }
            }
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
            "Leaves this Mac only when you run a check. Off by default."
        }
    }

    private func enableCopy(enabled: Bool, state: String, capability: CapabilityDescriptor) -> String {
        if enabled {
            if capability.accessLevel == .external {
                return "This source is on. It does not check the internet until you run a check."
            }
            return "This collector is on. Samples stay in the local store."
        }
        if state.lowercased().contains("denied") {
            return "Grant the required permission in System Settings, then turn this collector on."
        }
        if capability.accessLevel == .privileged {
            return "Authorize the extra right for this Mac, then turn the switch on."
        }
        if capability.accessLevel == .external {
            return "Turn the switch on, confirm the disclosure, then run a check when you want one."
        }
        return "Turn the switch on to start collecting this source."
    }

    private func enableDisclosure(_ capability: CapabilityDescriptor) -> String {
        "\(capability.summary) Method: \(capability.collectionMethod) Privacy class: \(privacyLabel(capability.privacyClass)). You can turn it off and delete its history afterward."
    }

    private func privacyLabel(_ privacy: PrivacyClass) -> String {
        switch privacy {
        case .operational: "Operational"
        case .identifyingDeviceContext: "Identifying device context"
        case .sensitiveActivityMetadata: "Sensitive activity metadata"
        case .content: "Content"
        }
    }

    private func dotColor(enabled: Bool, state: String) -> Color {
        if !enabled { return AppTheme.disabled }
        if state.lowercased().contains("denied") { return AppTheme.warning }
        if enabled { return AppTheme.success }
        return AppTheme.tertiary
    }

    private func domainLabel(_ domains: [TelemetryDomain]) -> String {
        domains.map(\.rawValue).joined(separator: ", ")
    }
}
