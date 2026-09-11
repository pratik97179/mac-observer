import Foundation
import MacObserverDomain

struct CapabilityPreferences {
    static let disabledKey = "macobserver.disabledCapabilities"
    static let enabledOptionalKey = "macobserver.enabledOptionalCapabilities"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(_ capability: CapabilityDescriptor) -> Bool {
        CapabilityPolicy.isEnabled(
            capability,
            disabledStandard: disabledStandardIDs(),
            enabledOptional: enabledOptionalIDs()
        )
    }

    func setEnabled(_ capability: CapabilityDescriptor, enabled: Bool) {
        if capability.defaultEnabled {
            var disabled = disabledStandardIDs()
            if enabled {
                disabled.remove(capability.id)
            } else {
                disabled.insert(capability.id)
            }
            defaults.set(Array(disabled), forKey: Self.disabledKey)
        } else {
            var enabledOptional = enabledOptionalIDs()
            if enabled {
                enabledOptional.insert(capability.id)
            } else {
                enabledOptional.remove(capability.id)
            }
            defaults.set(Array(enabledOptional), forKey: Self.enabledOptionalKey)
        }
    }

    func enabledIDs(from capabilities: [CapabilityDescriptor]) -> Set<String> {
        CapabilityPolicy.enabledIDs(
            capabilities: capabilities,
            disabledStandard: disabledStandardIDs(),
            enabledOptional: enabledOptionalIDs()
        )
    }

    private func disabledStandardIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.disabledKey) ?? [])
    }

    private func enabledOptionalIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.enabledOptionalKey) ?? [])
    }
}
