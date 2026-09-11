import SwiftUI

enum PanelLayout {
    static let tileSpacing: CGFloat = 20
    static let tileMinWidth: CGFloat = 190
    static let tileHeight: CGFloat = 168
    static let valueLineHeight: CGFloat = 34
    static let detailLineHeight: CGFloat = 16
    static let detailLines = 2
    static let tableRowCountOverview = 8
    static let tableRowCountProcesses = 20
    static let tableRowCountNetwork = 4
    static let eventListMinHeight: CGFloat = 280
    static let longestHealth = "Investigate"
    static let longestFreshness = "Stale · 99s ago"

    static var threeColumnMinWidth: CGFloat {
        tileMinWidth * 3 + tileSpacing * 2
    }

    static func metricColumns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: tileSpacing), count: count)
    }
}
