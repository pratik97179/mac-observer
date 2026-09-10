import SwiftUI

@main
struct MacObserverApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

private struct ContentView: View {
    @State private var selectedProfile: Profile = .overview

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selectedProfile)
        } detail: {
            OverviewView()
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.indigo)
    }
}

private enum Profile: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case performance = "Performance"
    case network = "Network"
    case processes = "Processes"
    case storage = "Storage"
    case power = "Power"
    case events = "Events"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .performance: "waveform.path.ecg"
        case .network: "network"
        case .processes: "square.stack.3d.up"
        case .storage: "internaldrive"
        case .power: "bolt"
        case .events: "clock.arrow.circlepath"
        }
    }
}

private struct Sidebar: View {
    @Binding var selection: Profile

    var body: some View {
        List(selection: $selection) {
            Section("Views") {
                ForEach(Profile.allCases) { profile in
                    Label(profile.rawValue, systemImage: profile.symbol)
                        .tag(profile)
                }
            }

            Section("System") {
                Label("Capabilities", systemImage: "checkmark.shield")
                Label("Settings", systemImage: "gearshape")
            }
        }
        .navigationTitle("Mac Observer")
        .listStyle(.sidebar)
    }
}

private struct OverviewView: View {
    private let readings = SystemReading.samples
    private let processes = ProcessActivity.samples

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                metrics
                activity
            }
            .padding(32)
            .frame(maxWidth: 1_280, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Search", systemImage: "magnifyingglass") {}
                    .keyboardShortcut("k", modifiers: .command)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 7) {
                Text("M4 Air")
                    .font(.system(size: 28, weight: .semibold))
                Text("A quiet look at your Mac, right now.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("Healthy", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
        }
    }

    private var metrics: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 190), spacing: 12)],
            spacing: 12
        ) {
            ForEach(readings) { reading in
                MetricTile(reading: reading)
            }
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Top Activity")
                    .font(.headline)
                Spacer()
                Text("Sample data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                GridRow {
                    Text("Process")
                    Text("CPU")
                    Text("Memory")
                    Text("Network")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                ForEach(processes) { process in
                    GridRow {
                        Label(process.name, systemImage: process.symbol)
                        Text(process.cpu)
                        Text(process.memory)
                        Text(process.network)
                    }
                    .font(.body.monospacedDigit())
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct MetricTile: View {
    let reading: SystemReading

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(reading.name, systemImage: reading.symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(reading.value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(reading.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(reading.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SystemReading: Identifiable {
    let name: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var id: String { name }

    static let samples = [
        SystemReading(name: "CPU", value: "32%", detail: "Normal load", symbol: "cpu", tint: .blue),
        SystemReading(name: "Memory", value: "11.8 GB", detail: "24 GB total", symbol: "memorychip", tint: .indigo),
        SystemReading(name: "Network", value: "2.4 MB/s", detail: "Downloading", symbol: "arrow.down.right", tint: .cyan),
        SystemReading(name: "Storage", value: "3%", detail: "I/O activity", symbol: "internaldrive", tint: .orange),
        SystemReading(name: "Power", value: "11.2 W", detail: "On battery", symbol: "bolt", tint: .yellow),
        SystemReading(name: "Thermal", value: "Normal", detail: "78% battery", symbol: "thermometer.medium", tint: .green)
    ]
}

private struct ProcessActivity: Identifiable {
    let name: String
    let cpu: String
    let memory: String
    let network: String
    let symbol: String

    var id: String { name }

    static let samples = [
        ProcessActivity(name: "Chrome", cpu: "14%", memory: "2.1 GB", network: "1.8 MB/s", symbol: "globe"),
        ProcessActivity(name: "Docker", cpu: "8%", memory: "1.4 GB", network: "420 KB/s", symbol: "shippingbox"),
        ProcessActivity(name: "Xcode", cpu: "6%", memory: "1.1 GB", network: "92 KB/s", symbol: "hammer")
    ]
}
