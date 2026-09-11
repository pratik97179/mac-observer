import Foundation
import SystemConfiguration

public struct NetworkPathSnapshot: Sendable, Equatable {
    public var primaryInterface: String?
    public var gateway: String?
    public var dnsServers: [String]

    public init(primaryInterface: String? = nil, gateway: String? = nil, dnsServers: [String] = []) {
        self.primaryInterface = primaryInterface
        self.gateway = gateway
        self.dnsServers = Array(dnsServers.prefix(Self.dnsLimit))
    }

    public static let dnsLimit = 3

    public var signature: String {
        [primaryInterface ?? "", gateway ?? "", dnsServers.joined(separator: ",")].joined(separator: "|")
    }

    public var isEmpty: Bool {
        primaryInterface == nil && gateway == nil && dnsServers.isEmpty
    }
}

public protocol NetworkPathSource: Sendable {
    func currentPath() -> NetworkPathSnapshot?
}

public struct SystemConfigurationPathSource: NetworkPathSource {
    public init() {}

    public func currentPath() -> NetworkPathSnapshot? {
        guard let store = SCDynamicStoreCreate(nil, "MacObserver.network" as CFString, nil, nil) else {
            return nil
        }
        let ipv4 = dictionary(store, key: "State:/Network/Global/IPv4")
        let ipv6 = dictionary(store, key: "State:/Network/Global/IPv6")
        let dns = dictionary(store, key: "State:/Network/Global/DNS")
        let primary = string(ipv4, "PrimaryInterface") ?? string(ipv6, "PrimaryInterface")
        let gateway = sanitizedAddress(string(ipv4, "Router")) ?? sanitizedAddress(string(ipv6, "Router"))
        let servers = (dns?["ServerAddresses"] as? [String] ?? []).compactMap(sanitizedAddress)
        let path = NetworkPathSnapshot(
            primaryInterface: sanitizedInterface(primary),
            gateway: gateway,
            dnsServers: servers
        )
        return path
    }

    private func dictionary(_ store: SCDynamicStore, key: String) -> [String: Any]? {
        SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any]
    }

    private func string(_ dictionary: [String: Any]?, _ key: String) -> String? {
        dictionary?[key] as? String
    }

    private func sanitizedInterface(_ name: String?) -> String? {
        guard let name, (1...16).contains(name.count),
              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            return nil
        }
        return name
    }

    private func sanitizedAddress(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...45).contains(trimmed.count) else { return nil }
        guard trimmed.allSatisfy({ $0.isASCII && ($0.isHexDigit || $0 == "." || $0 == ":") }) else { return nil }
        return trimmed
    }
}
