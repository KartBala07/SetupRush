import SwiftUI

// MARK: - App state

enum Screen { case landing, hub, patterns, career }

struct GameConfig: Identifiable {
    let id = UUID()
    var mode: GameMode
    var market: Market
    var arena: Bool = false
}

@MainActor
final class AppState: ObservableObject {
    @Published var career = CareerStats.load()
    @Published var screen: Screen = .landing
    @Published var game: GameConfig?
    @Published var lastResult: RunResult?

    func record(_ r: RunResult) {
        career.runs += 1
        career.trades += r.trades.count
        career.wins += r.trades.filter(\.win).count
        career.best = max(career.best, r.pnl)
        career.netPnl += r.pnl
        let xp = max(0, Int(r.pnl / 4)) + r.trades.count * 12 + r.correctCalls * 25
        career.xp += xp
        career.wicks += max(0, Int(r.pnl / 10)) + (r.pnl > 0 ? 5 : 0)
        career.lastPnl = r.pnl
        career.lastMode = r.mode.title
        career.lastMarket = r.marketName
        career.lastTrades = r.trades.count
        career.lastWinRate = r.winRate
        career.lastSetups = r.setupsSeen
        career.lastEquity = Array(r.equityCurve.suffix(120))
        career.hasRun = true
        let levelBefore = career.level
        career.save()
        lastResult = r
        if career.level > levelBefore { Haptic.success() }
    }

    func start(mode: GameMode, market: Market, arena: Bool = false) {
        Haptic.medium()
        game = GameConfig(mode: mode, market: market, arena: arena)
    }
}

// MARK: - Root

struct RootView: View {
    @StateObject private var app = AppState()

    var body: some View {
        ZStack {
            Ink.bg.ignoresSafeArea()
            Group {
                switch app.screen {
                case .landing: LandingView()
                case .hub: PlayHubView()
                case .patterns: PatternsView()
                case .career: CareerView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.22), value: app.screen)
        }
        .environmentObject(app)
        .preferredColorScheme(.dark)
        .onAppear(perform: applyLaunchFlags)
        .fullScreenCover(item: $app.game) { cfg in
            GameView(config: cfg)
                .environmentObject(app)
        }
    }
}

extension RootView {
    /// Debug-only entry points: `-screen hub|patterns|career|game -mode pro|rush|callit|blowup|sniper`
    func applyLaunchFlags() {
        let d = UserDefaults.standard
        if let s = d.string(forKey: "screen") {
            switch s {
            case "hub": app.screen = .hub
            case "patterns": app.screen = .patterns
            case "career": app.screen = .career
            case "game":
                let mode = GameMode(rawValue: d.string(forKey: "mode") ?? "pro") ?? .pro
                if let m = MarketStore.shared.markets.first { app.start(mode: mode, market: m) }
            default: break
            }
        }
        if d.bool(forKey: "resetCareer") {
            app.career = CareerStats()
            app.career.save()
        }
    }
}

@main
struct SetupRushApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
