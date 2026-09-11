import Foundation

public struct BootSessionID: Sendable, Hashable, Codable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}

public struct ProcessAttributes: Sendable, Hashable, Codable {
    public var displayName: String?
    public var bundleIdentifier: String?
    public var executablePath: String?
    public var signingIdentity: String?
    public var parentPID: Int32?
    public var parentStartNanoseconds: UInt64?

    public init(
        displayName: String? = nil,
        bundleIdentifier: String? = nil,
        executablePath: String? = nil,
        signingIdentity: String? = nil,
        parentPID: Int32? = nil,
        parentStartNanoseconds: UInt64? = nil
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.executablePath = executablePath
        self.signingIdentity = signingIdentity
        self.parentPID = parentPID
        self.parentStartNanoseconds = parentStartNanoseconds
    }
}

public struct ProcessInstanceIdentity: Sendable, Codable {
    public let pid: Int32
    public let startNanoseconds: UInt64
    public let bootSession: BootSessionID
    public var attributes: ProcessAttributes

    public init(
        pid: Int32,
        startNanoseconds: UInt64,
        bootSession: BootSessionID,
        attributes: ProcessAttributes = ProcessAttributes()
    ) {
        self.pid = pid
        self.startNanoseconds = startNanoseconds
        self.bootSession = bootSession
        self.attributes = attributes
    }

    public var identityKey: String {
        "\(bootSession.value):\(pid):\(startNanoseconds)"
    }
}

extension ProcessInstanceIdentity: Hashable {
    public static func == (lhs: ProcessInstanceIdentity, rhs: ProcessInstanceIdentity) -> Bool {
        lhs.pid == rhs.pid
            && lhs.startNanoseconds == rhs.startNanoseconds
            && lhs.bootSession == rhs.bootSession
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(startNanoseconds)
        hasher.combine(bootSession)
    }
}

public enum Entity: Sendable, Hashable, Codable {
    case system(bootSession: BootSessionID)
    case processInstance(ProcessInstanceIdentity)
    case app(bundleIdentifier: String)
    case networkInterface(name: String, hardwareID: String?)
    case volume(uuid: String)
    case device(stableID: String)
    case capability(id: String)

    public var identityKey: String {
        switch self {
        case .system(let bootSession):
            "system:\(bootSession.value)"
        case .processInstance(let process):
            "process:\(process.identityKey)"
        case .app(let bundleIdentifier):
            "app:\(bundleIdentifier)"
        case .networkInterface(let name, let hardwareID):
            "iface:\(name):\(hardwareID ?? "")"
        case .volume(let uuid):
            "volume:\(uuid)"
        case .device(let stableID):
            "device:\(stableID)"
        case .capability(let id):
            "capability:\(id)"
        }
    }

    public var displayTitle: String {
        switch self {
        case .system:
            "This Mac"
        case .processInstance(let process):
            process.attributes.displayName ?? "PID \(process.pid)"
        case .app(let bundleIdentifier):
            bundleIdentifier
        case .networkInterface(let name, _):
            name
        case .volume(let uuid):
            uuid
        case .device(let stableID):
            stableID
        case .capability(let id):
            id
        }
    }
}
