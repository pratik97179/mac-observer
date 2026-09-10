import Foundation

struct CapabilityPreferences {
    static let disabledKey = "macobserver.disabledCapabilities"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(_ id: String) -> Bool {
        !disabledIDs().contains(id)
    }

    func setEnabled(_ id: String, enabled: Bool) {
        var disabled = disabledIDs()
        if enabled {
            disabled.remove(id)
        } else {
            disabled.insert(id)
        }
        defaults.set(Array(disabled), forKey: Self.disabledKey)
    }

    func enabledIDs(from known: [String]) -> Set<String> {
        let disabled = disabledIDs()
        return Set(known.filter { !disabled.contains($0) })
    }

    private func disabledIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.disabledKey) ?? [])
    }
}