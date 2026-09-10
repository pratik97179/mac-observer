import SwiftUI

struct SettingsView: View {
    @Bindable var store: OverviewStore
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                retentionCard
                historyCard
                appearanceCard
            }
            .padding(32)
            .frame(maxWidth: 880, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Settings")
        .confirmationDialog(
            "Delete all locally stored metrics and events? Live readings continue. This cannot be undone.",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete local history", role: .destructive) {
                Task { await store.deleteLocalHistory() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Settings")
                .font(.system(size: 28, weight: .semibold))
            Text("History stays on this Mac. There is no account and no upload.")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 640, alignment: .leading)
        }
    }

    private var retentionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Retention")
                .font(.headline)
            Text("Metrics older than 7 days are removed. Events older than 30 days are removed. Downsampled long-term history is not shipped yet.")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Policy is applied at launch and about every five minutes while the app runs.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local history")
                .font(.headline)
            if let path = store.historyPath {
                Text(path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("No SQLite file is open. Live readings are not being saved.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if let message = store.historyMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Delete local history…") {
                confirmDelete = true
            }
            .disabled(store.historyPath == nil)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(.headline)
            Text("Follows the system appearance. There is no separate theme yet.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
}