import Foundation

// MARK: - Candle

struct Candle: Identifiable, Equatable {
    let t: Double          // unix seconds
    let o: Double
    let h: Double
    let l: Double
    let c: Double
    let v: Double
    var id: Double { t }

    var isUp: Bool { c >= o }
    var body: Double { abs(c - o) }
    var range: Double { max(h - l, 0.0000001) }
    var mid: Double { (h + l) / 2 }
}

extension Candle {
    /// Interpolated price along the recorded OHLC path (O → H/L → L/H → C).
    func subPrice(_ p: Double) -> Double {
        let legs: [(Double, Double)] = c >= o
            ? [(0, o), (0.20, l), (0.56, h), (0.82, c), (1, c)]
            : [(0, o), (0.20, h), (0.56, l), (0.82, c), (1, c)]
        let t = min(max(p, 0), 1)
        for i in 0..<(legs.count - 1) {
            let (p0, v0) = legs[i]
            let (p1, v1) = legs[i + 1]
            if t <= p1 {
                let f = p1 == p0 ? 1 : (t - p0) / (p1 - p0)
                return v0 + (v1 - v0) * f
            }
        }
        return c
    }
}

// MARK: - Market

struct Market: Identifiable, Equatable {
    let symbol: String        // "BTC-USD"
    let base: String          // "BTC"
    let quote: String         // "USD"
    let candles: [Candle]

    var id: String { symbol }
    var name: String { "\(base)/\(quote)" }
    var last: Double { candles.last?.c ?? 0 }

    var change24h: Double {
        guard candles.count > 96 else { return 0 }
        let then = candles[candles.count - 97].c
        guard then > 0 else { return 0 }
        return (last - then) / then * 100
    }

    var spark: [Double] { candles.suffix(64).map(\.c) }
}

// MARK: - Store

final class MarketStore: ObservableObject {
    static let shared = MarketStore()
    @Published private(set) var markets: [Market] = []

    private struct Root: Decodable {
        let granularity: Int
        let generated: Double
        let markets: [String: Wrapped]
    }
    private struct Wrapped: Decodable {
        let candles: [[Double]]
    }

    init() { load() }

    private func load() {
        guard let url = Bundle.main.url(forResource: "markets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return
        }
        var built: [Market] = []
        let order = ["BTC-USD", "ETH-USD", "SOL-USD", "DOGE-USD", "LINK-USD", "AVAX-USD", "XRP-USD", "SUI-USD"]
        for symbol in order {
            guard let w = root.markets[symbol] else { continue }
            let cs: [Candle] = w.candles.compactMap { r in
                guard r.count >= 6 else { return nil }
                return Candle(t: r[0], o: r[1], h: r[2], l: r[3], c: r[4], v: r[5])
            }
            let parts = symbol.split(separator: "-")
            built.append(Market(symbol: symbol,
                                base: String(parts[0]),
                                quote: parts.count > 1 ? String(parts[1]) : "USD",
                                candles: cs))
        }
        markets = built
    }

    var timeframes: String { "15M" }
}

// MARK: - Mode

enum GameMode: String, CaseIterable, Identifiable, Codable {
    case rush, pro, blowup, callit, sniper, career

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rush: return "RUSH"
        case .pro: return "PRO"
        case .blowup: return "BLOW-UP"
        case .callit: return "CALL IT"
        case .sniper: return "SNIPER"
        case .career: return "CAREER"
        }
    }

    var tagline: String {
        switch self {
        case .rush: return "Spot only. Long only."
        case .pro: return "Perps. Long and short."
        case .blowup: return "Leverage ramps. Bank must live."
        case .callit: return "Name the direction. Three lives."
        case .sniper: return "One trade. Make it count."
        case .career: return "Rank up from intern."
        }
    }

    var icon: String {
        switch self {
        case .rush: return "figure.run"
        case .pro: return "arrow.up.arrow.down"
        case .blowup: return "flame.fill"
        case .callit: return "hand.point.up.left.fill"
        case .sniper: return "scope"
        case .career: return "chart.bar.fill"
        }
    }

    var leverage: Double {
        switch self {
        case .rush, .career: return 1
        case .pro: return 25
        case .blowup: return 25
        case .callit: return 1
        case .sniper: return 10
        }
    }

    var allowsShort: Bool { self == .pro || self == .sniper || self == .blowup }

    var duration: Double {
        switch self {
        case .callit: return 75
        case .sniper: return 90
        default: return 60
        }
    }

    var candlesToPlay: Int {
        switch self {
        case .sniper: return 55
        case .callit: return 60
        default: return 40
        }
    }

    var accent: String {
        switch self {
        case .rush: return "SPOT · LONG ONLY"
        case .pro: return "LONG · SHORT"
        case .blowup: return "25× → 100×"
        case .callit: return "UP OR DOWN"
        case .sniper: return "10× · 1 TRADE"
        case .career: return "1× · PROGRESS"
        }
    }
}

// MARK: - Setups / patterns

struct Setup: Identifiable, Equatable {
    let id = UUID()
    var pattern: PatternKind
    var direction: Int          // +1 bullish, -1 bearish
    var entry: Double
    var stop: Double
    var target: Double
    var confirmedAt: Int        // candle index in series
    var status: SetupStatus = .forming

    var rMultiple: Double {
        guard entry != stop else { return 1 }
        return abs(target - entry) / abs(entry - stop)
    }
    var riskPct: Double { abs(entry - stop) / entry * 100 }
}

enum SetupStatus: String {
    case forming, confirmed, target, stopped, expired
}

struct Trade: Identifiable, Equatable {
    let id = UUID()
    var direction: Int
    var entry: Double
    var exit: Double
    var pnl: Double
    var atIndex: Int
    var setupName: String?

    var win: Bool { pnl > 0 }
    var movePct: Double { Double(direction) * (exit - entry) / entry * 100 }
}

// MARK: - Persistence

struct CareerStats: Codable {
    var xp: Int = 0
    var runs: Int = 0
    var trades: Int = 0
    var wins: Int = 0
    var best: Double = 0
    var wicks: Int = 150
    var netPnl: Double = 0

    // last run summary (persisted so Career survives relaunches)
    var lastPnl: Double = 0
    var lastMode: String = ""
    var lastMarket: String = ""
    var lastTrades: Int = 0
    var lastWinRate: Double = 0
    var lastSetups: Int = 0
    var lastEquity: [Double] = []
    var hasRun: Bool = false

    init() {}

    // Tolerant decoding: older saves without the last-run fields still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        runs = try c.decodeIfPresent(Int.self, forKey: .runs) ?? 0
        trades = try c.decodeIfPresent(Int.self, forKey: .trades) ?? 0
        wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        best = try c.decodeIfPresent(Double.self, forKey: .best) ?? 0
        wicks = try c.decodeIfPresent(Int.self, forKey: .wicks) ?? 150
        netPnl = try c.decodeIfPresent(Double.self, forKey: .netPnl) ?? 0
        lastPnl = try c.decodeIfPresent(Double.self, forKey: .lastPnl) ?? 0
        lastMode = try c.decodeIfPresent(String.self, forKey: .lastMode) ?? ""
        lastMarket = try c.decodeIfPresent(String.self, forKey: .lastMarket) ?? ""
        lastTrades = try c.decodeIfPresent(Int.self, forKey: .lastTrades) ?? 0
        lastWinRate = try c.decodeIfPresent(Double.self, forKey: .lastWinRate) ?? 0
        lastSetups = try c.decodeIfPresent(Int.self, forKey: .lastSetups) ?? 0
        lastEquity = try c.decodeIfPresent([Double].self, forKey: .lastEquity) ?? []
        hasRun = try c.decodeIfPresent(Bool.self, forKey: .hasRun) ?? false
    }

    static let key = "sr.career.v1"
    static func load() -> CareerStats {
        guard let d = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(CareerStats.self, from: d) else { return CareerStats() }
        return s
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(d, forKey: CareerStats.key)
        }
    }

    var level: Int { max(1, xp / 500 + 1) }
    var rank: String {
        switch level {
        case 1: return "INTERN"
        case 2: return "JUNIOR"
        case 3: return "ANALYST"
        case 4: return "TRADER"
        case 5: return "DESK HEAD"
        case 6: return "PM"
        default: return "LEGEND"
        }
    }
    var winRate: Double { trades == 0 ? 0 : Double(wins) / Double(trades) * 100 }
}

// MARK: - Seeded RNG (deterministic chart windows)

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
