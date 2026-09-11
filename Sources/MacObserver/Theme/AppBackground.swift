import SwiftUI
import MacObserverDomain
import MacObserverCollectors

enum AtmosphereState: Equatable {
    case calm
    case active
    case critical

    var globalDarkening: Double {
        switch self {
        case .calm: 0.42
        case .active: 0.38
        case .critical: 0.48
        }
    }

    var wash: Double {
        switch self {
        case .critical: 0.03
        default: 0
        }
    }

    static func from(snapshot: LiveSnapshot) -> AtmosphereState {
        let model = OverviewModel.from(snapshot: snapshot)
        switch model.health.state {
        case .investigate:
            return .critical
        case .attention:
            return .active
        case .healthy:
            let cpu = snapshot.metrics.first { metric in
                if case .system = metric.entity {
                    return metric.name == .cpuUtilizationRatio
                }
                return false
            }
            if let cpu, case .ratio(let value) = cpu.value, value >= 0.45 {
                return .active
            }
            return .calm
        }
    }
}

enum BackgroundDebugStage: String, CaseIterable, Identifiable {
    case environment
    case darkening
    case readability
    case atmospheric
    case production

    var id: String { rawValue }

    var title: String {
        switch self {
        case .environment: "Environmental only"
        case .darkening: "+ Darkening"
        case .readability: "+ Readability"
        case .atmospheric: "+ Atmospheric tint"
        case .production: "Production"
        }
    }

    var showsDarkening: Bool {
        self != .environment
    }

    var showsReadability: Bool {
        self == .readability || self == .atmospheric || self == .production
    }

    var showsAtmospheric: Bool {
        self == .atmospheric || self == .production
    }
}

struct AppBackground: View {
    var state: AtmosphereState = .calm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if DEBUG
    @AppStorage("MacObserver.backgroundDebugStage") private var debugStageRaw = BackgroundDebugStage.production.rawValue
    #endif

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 24, paused: reduceMotion)) { context in
            let drift = luminanceDrift(at: context.date)
            let stage = debugStage
            ZStack {
                EnvironmentBackgroundImage()
                if stage.showsDarkening {
                    GlobalDarkeningLayer(opacity: min(state.globalDarkening, 0.55))
                }
                if stage.showsReadability {
                    ReadabilityField()
                }
                if stage.showsAtmospheric {
                    AtmosphericTint(drift: drift)
                    if state.wash > 0 {
                        criticalWash
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var debugStage: BackgroundDebugStage {
        #if DEBUG
        BackgroundDebugStage(rawValue: debugStageRaw) ?? .production
        #else
        .production
        #endif
    }

    private var criticalWash: some View {
        RadialGradient(
            colors: [
                Theme.Color.critical.opacity(state.wash),
                .clear
            ],
            center: UnitPoint(x: 0.58, y: 0.38),
            startRadius: 20,
            endRadius: 520
        )
    }

    private func luminanceDrift(at date: Date) -> Double {
        if reduceMotion || Motion.reduceMotion { return 0 }
        let period = 16.0
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return 0.012 * sin(phase * 2 * .pi)
    }
}

struct EnvironmentBackgroundImage: View {
    var body: some View {
        GeometryReader { proxy in
            AppImage.environmentBackdrop()
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GlobalDarkeningLayer: View {
    var opacity: Double

    var body: some View {
        Color.black.opacity(opacity)
    }
}

struct ReadabilityField: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.58, y: 0.36),
                startRadiusFraction: 0.08,
                endRadiusFraction: 0.72
            )
            EllipticalGradient(
                colors: [
                    Color.black.opacity(0.16),
                    .clear
                ],
                center: UnitPoint(x: 0.58, y: 0.18),
                startRadiusFraction: 0.02,
                endRadiusFraction: 0.28
            )
        }
        .allowsHitTesting(false)
    }
}

struct AtmosphericTint: View {
    var drift: Double = 0

    var body: some View {
        RadialGradient(
            colors: [
                Color(red: 0.28, green: 0.34, blue: 0.58).opacity(0.035 + max(drift, 0) * 0.4),
                .clear
            ],
            center: UnitPoint(x: 0.62, y: 0.28),
            startRadius: 40,
            endRadius: 980
        )
        .allowsHitTesting(false)
    }
}

#if DEBUG
struct BackgroundDebugCommands: Commands {
    @AppStorage("MacObserver.backgroundDebugStage") private var debugStageRaw = BackgroundDebugStage.production.rawValue

    var body: some Commands {
        CommandMenu("Background") {
            ForEach(BackgroundDebugStage.allCases) { stage in
                Button(stage.title) {
                    debugStageRaw = stage.rawValue
                }
            }
        }
    }
}
#endif
