import SwiftUI
import MacObserverDomain

struct CapabilitiesView: View {
    @Bindable var store: OverviewStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                ForEach(store.capabilities) { capability in
                    capabilityCard(capability)
                }
            }
            .padding(32)
            .frame(maxWidth: 880, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Capabilities")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Capabilities")
                .font(.system(size: 28, weight: .semibold))
            Text("Standard collectors stay on this Mac. Turning one off stops future samples from that source.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 640, alignment: .leading)
        }
    }

    private func capabilityCard(_ capability: CapabilityDescriptor) -> some View {
        let enabled = store.isCapabilityEnabled(capability.id)
        let state = store.capabilityState(capability.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(capability.title)
                        .font(.headline)
                    Text(accessLabel(capability.accessLevel))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: enabledBinding(capability.id))
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Text(capability.summary)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label(state, systemImage: enabled ? "checkmark.circle" : "pause.circle")
                Label("Local only", systemImage: "internaldrive")
                Label(domainLabel(capability.domains), systemImage: "square.grid.2x2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
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

    private func domainLabel(_ domains: [TelemetryDomain]) -> String {
        domains.map(\.rawValue).joined(separator: ", ")
    }
}