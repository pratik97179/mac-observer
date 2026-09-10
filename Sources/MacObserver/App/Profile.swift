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
            "CPU, memory, pressure, and thermal from the live host collectors."
        case .network:
            "Interface receive and transmit rates. Not per-process."
        case .processes:
            "Process identity, CPU, and resident memory from proc_pidinfo."
        case .storage:
            "Root volume capacity and system block I/O."
        case .power:
            "Battery, watts, and thermal state from IOKit and ProcessInfo."
        case .events:
            "Stored discrete changes. Choose 1 hour, 24 hours, or 7 days."
        case .capabilities:
            "Each data source, its access level, and how to turn it off."
        case .settings:
            "Retention and local history. Appearance follows the system."
        }
    }
}
