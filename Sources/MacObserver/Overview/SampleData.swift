import SwiftUI

struct SystemReading: Identifiable {
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

struct ProcessActivity: Identifiable {
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
