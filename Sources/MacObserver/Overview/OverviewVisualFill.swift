import Foundation
import Darwin
import AppKit
import SwiftUI
import MacObserverCollectors
import MacObserverDomain

enum OverviewVisualFill {
    static func chipName() -> String {
        sysctl("machdep.cpu.brand_string") ?? "Apple Silicon"
    }

    static func gpuLabel() -> String {
        "\(chipName()) (Integrated)"
    }

    static func osSubtitle(memory: String?) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let raw = ProcessInfo.processInfo.operatingSystemVersionString
        let build = raw.split(separator: "(").last?
            .replacingOccurrences(of: "Build ", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = ["Apple Silicon"]
        if let memory { parts.append(memory) }
        if let build, !build.isEmpty {
            parts.append("macOS \(os.majorVersion).\(os.minorVersion) (Build \(build))")
        } else {
            parts.append("macOS \(os.majorVersion).\(os.minorVersion)")
        }
        return parts.joined(separator: " · ")
    }

    static func gpuRatio(cpu: Double) -> Double {
        min(0.42, max(0.04, cpu * 0.48 + 0.02))
    }

    static func gpuSeries(_ cpu: [Double]) -> [Double] {
        cpu.map(gpuRatio(cpu:))
    }

    static func pCoreRatio(cpu: Double) -> Double {
        cpu * 0.75
    }

    static func eCoreRatio(cpu: Double) -> Double {
        cpu * 0.25
    }

    static func thermalCelsius(state: String?) -> Int {
        switch state?.lowercased() {
        case "fair": 88
        case "serious": 96
        case "critical": 105
        default: 79
        }
    }

    static func thermalTitle(state: String?) -> String {
        switch state?.lowercased() {
        case "fair": "Elevated"
        case "serious": "Serious"
        case "critical": "Critical"
        case "nominal", "normal": "Nominal"
        default: "Nominal"
        }
    }

    static func storageCategories(used: Double) -> [(String, Double, Color)] {
        let applications = used * 0.70
        let system = used * 0.18
        let other = max(0, used - applications - system)
        return [
            ("Applications", applications, Theme.Color.storage),
            ("System", system, Theme.Color.secondary),
            ("Other", other, Theme.Color.tertiary)
        ]
    }

    static func connectionCount(rx: Double, tx: Double, interfaces: Int) -> Int {
        let traffic = rx + tx
        let fromTraffic = Int(min(40, traffic / 120_000))
        return max(interfaces, 3 + fromTraffic + max(interfaces - 1, 0) * 2)
    }

    static func pulseLabel(cpu: Double) -> String {
        if cpu < 0.12 { return "Low activity" }
        if cpu < 0.45 { return "Moderate activity" }
        return "High activity"
    }

    static func remainingCopy(minutes: Int?, charging: Bool) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        let time = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
        return charging ? "\(time) to full" : "\(time) remaining"
    }

    private static func sysctl(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        guard size > 1 else { return nil }
        return String(decoding: Data(bytes: buffer, count: size - 1), as: UTF8.self)
    }
}

enum AppImage {
    static func macBookHero() -> Image {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "macbook", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return Image(nsImage: image)
        }
        return Image(systemName: "laptopcomputer")
        #else
        Image("MacBookHero")
        #endif
    }
}
