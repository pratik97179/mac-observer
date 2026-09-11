import SwiftUI

struct SettingsView: View {
    @Bindable var store: OverviewStore
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.section) {
                VStack(alignment: .leading, spacing: Theme.Space.compact) {
                    Text("Settings")
                        .font(Theme.Typography.pageTitle)
                    Text("History stays on this Mac. There is no account and no upload.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Color.secondary)
                        .frame(maxWidth: 640, alignment: .leading)
                }

                settingsGroup(title: "Retention") {
                    Text("Raw metrics stay for 7 days, then roll into 15-minute averages kept for 90 days. Events older than 30 days are removed.")
                    Text("This policy is documented here. It is not editable in the app. It is applied at launch and about every five minutes while the app runs.")
                        .foregroundStyle(Theme.Color.tertiary)
                }

                settingsGroup(title: "Local history") {
                    if let path = store.historyPath {
                        Text(path)
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.Color.secondary)
                            .textSelection(.enabled)
                    } else {
                        Text("No SQLite file is open. Live readings are not being saved.")
                    }
                    if let message = store.historyMessage {
                        Text(message)
                            .foregroundStyle(Theme.Color.secondary)
                    }
                    Button("Delete local history…") {
                        confirmDelete = true
                    }
                    .disabled(store.historyPath == nil)
                    .tint(Theme.Color.accent)
                }

                settingsGroup(title: "Appearance") {
                    Text("The cockpit is always dark. Color is reserved for health and selection.")
                }

                #if DEBUG
                settingsGroup(title: "Design system") {
                    NavigationLink("Open preview") {
                        DesignSystemPreview()
                    }
                    .foregroundStyle(Theme.Color.accent)
                }
                #endif
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Color.secondary)
            .frame(maxWidth: 880, alignment: .leading)
            .instrumentContent()
        }
        .instrumentScreen()
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

    private func settingsGroup(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.compact) {
            Text(title)
                .font(Theme.Typography.section)
                .foregroundStyle(Theme.Color.tertiary)
            content()
        }
        .padding(Theme.Space.standard)
        .glass(.elevated, radius: Theme.Radius.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
