import Foundation
import Darwin
import AppKit
import SwiftUI
import MacObserverDomain

enum OverviewVisualFill {
    static func chipName() -> String {
        sysctl("machdep.cpu.brand_string") ?? "Unknown processor"
    }

    static func osSubtitle(memory: String?) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var parts = [chipName()]
        if let memory { parts.append(memory) }
        parts.append("macOS \(os.majorVersion).\(os.minorVersion)")
        return parts.joined(separator: "  ·  ")
    }

    static func thermalTitle(state: String?) -> String {
        switch state?.lowercased() {
        case "fair": "Fair"
        case "serious": "Serious"
        case "critical": "Critical"
        case "nominal", "normal": "Nominal"
        case nil: "Waiting"
        default: state?.capitalized ?? "Waiting"
        }
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
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cachedHero: NSImage?

    static func macBookHero() -> Image? {
        guard let image = preparedMacBook() else { return nil }
        return Image(nsImage: image)
    }

    private static func preparedMacBook() -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cachedHero { return cachedHero }
        guard let source = loadMacBookSource() else { return nil }
        let prepared = blendMachineVisual(source) ?? source
        cachedHero = prepared
        return prepared
    }

    private static func loadMacBookSource() -> NSImage? {
        if let image = NSImage(named: "MacBookHero"), image.size.width > 8 {
            return image
        }
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "macbook", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        #endif
        if let url = Bundle.main.url(forResource: "macbook", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    private static func blendMachineVisual(_ image: NSImage) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cg.width
        let height = cg.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        let centerX = Double(width) * 0.5
        let centerY = Double(height) * 0.55
        let radiusX = Double(width) * 0.50
        let radiusY = Double(height) * 0.50
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let alphaByte = Double(pixels[index + 3])
                if alphaByte == 0 { continue }
                let red = min(1, Double(pixels[index]) / alphaByte)
                let green = min(1, Double(pixels[index + 1]) / alphaByte)
                let blue = min(1, Double(pixels[index + 2]) / alphaByte)
                let alpha = alphaByte / 255
                let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                let chroma = max(red, green, blue) - min(red, green, blue)
                let dx = (Double(x) - centerX) / radiusX
                let dy = (Double(y) - centerY) / radiusY
                let distance = sqrt(dx * dx + dy * dy)
                let keep = luma > 0.20 || chroma > 0.16
                let fade = keep ? 0.0 : Self.smoothstep(0.28, 0.82, distance)
                let nextAlpha = alpha * (1 - fade)
                if nextAlpha < 0.02 {
                    pixels[index] = 0
                    pixels[index + 1] = 0
                    pixels[index + 2] = 0
                    pixels[index + 3] = 0
                    continue
                }
                let scale = nextAlpha / alpha
                pixels[index] = UInt8((Double(pixels[index]) * scale).rounded())
                pixels[index + 1] = UInt8((Double(pixels[index + 1]) * scale).rounded())
                pixels[index + 2] = UInt8((Double(pixels[index + 2]) * scale).rounded())
                pixels[index + 3] = UInt8((nextAlpha * 255).rounded())
                if x < minX { minX = x }
                if y < minY { minY = y }
                if x > maxX { maxX = x }
                if y > maxY { maxY = y }
            }
        }

        guard minX <= maxX, minY <= maxY, let full = context.makeImage() else { return nil }
        let pad = 12
        minX = max(0, minX - pad)
        minY = max(0, minY - pad)
        maxX = min(width - 1, maxX + pad)
        maxY = min(height - 1, maxY + pad)
        let crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = full.cropping(to: crop) else { return nil }
        return NSImage(
            cgImage: cropped,
            size: NSSize(width: CGFloat(cropped.width) / 2, height: CGFloat(cropped.height) / 2)
        )
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> Double {
        let t = max(0, min(1, (value - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    static func environmentBackdrop() -> Image {
        lock.lock()
        defer { lock.unlock() }
        if let cachedBackdrop {
            return Image(nsImage: cachedBackdrop)
        }
        let loaded: NSImage? = {
            if let image = NSImage(named: "EnvironmentBackdrop") { return image }
            if let url = Bundle.main.url(forResource: "bg", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
            return nil
        }()
        if let loaded {
            cachedBackdrop = loaded
            return Image(nsImage: loaded)
        }
        return Image("EnvironmentBackdrop")
    }

    nonisolated(unsafe) private static var cachedBackdrop: NSImage?
}
