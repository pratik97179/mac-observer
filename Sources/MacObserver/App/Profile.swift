enum Profile: String, Identifiable, Hashable {
    case overview = "Overview"
    case performance = "Performance"
    case network = "Network"
    case processes = "Processes"
    case storage = "Storage"
    case power = "Power"
    case events = "Events"
    case capabilities = "Capabilities"
    case settings = "Settings"

    var id: Self { self }

    static let views: [Profile] = [
        .overview, .performance, .network, .processes, .storage, .power, .events
    ]

    static let system: [Profile] = [
        .capabilities, .settings
    ]

    var symbol: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .performance: "waveform.path.ecg"
        case .network: "network"
        case .processes: "square.stack.3d.up"
        case .storage: "internaldrive"
        case .power: "bolt"
        case .events: "clock.arrow.circlepath"
        case .capabilities: "checkmark.shield"
        case .settings: "gearshape"
        }
    }

    var placeholderSummary: String {
        switch self {
        case .overview:
            "Current machine health and top resource use."
        case .performance:
            "CPU, memory, and thermal history will land here after live collectors."
        case .network:
            "Interface throughput and link state will land here after live collectors."
        case .processes:
            "Process identity, CPU, and memory will land here after live collectors."
        case .storage:
            "Volume capacity and I/O will land here after live collectors."
        case .power:
            "Battery, watts, and thermal state will land here after live collectors."
        case .events:
            "A filtered timeline of meaningful changes will land here later."
        case .capabilities:
            "Each data source, its access level, and how to turn it off."
        case .settings:
            "Retention, appearance, and local history controls."
        }
    }
}
