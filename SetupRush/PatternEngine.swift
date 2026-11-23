import Foundation

// MARK: - Pattern catalog

struct PatternKind: Hashable, Identifiable {
    let key: String
    let name: String
    let bias: Int          // +1 bullish, -1 bearish, 0 neutral
    let note: String
    var id: String { key }

    var biasLabel: String {
        switch bias {
        case 1: return "BULLISH"
        case -1: return "BEARISH"
        default: return "NEUTRAL"
        }
    }
}

enum PatternBook {
    static let all: [PatternKind] = [
        .init(key: "bull_flag", name: "Bull Flag", bias: 1, note: "Impulse, tight drift, continuation."),
        .init(key: "bear_flag", name: "Bear Flag", bias: -1, note: "Drop, weak bounce, continuation down."),
        .init(key: "hammer", name: "Hammer", bias: 1, note: "Long lower wick rejecting the low."),
        .init(key: "shooting_star", name: "Shooting Star", bias: -1, note: "Long upper wick rejecting the high."),
        .init(key: "bull_engulfing", name: "Bullish Engulfing", bias: 1, note: "Body swallows the prior candle."),
        .init(key: "bear_engulfing", name: "Bearish Engulfing", bias: -1, note: "Sellers swallow the prior candle."),
        .init(key: "morning_star", name: "Morning Star", bias: 1, note: "Three-candle reversal off the low."),
        .init(key: "evening_star", name: "Evening Star", bias: -1, note: "Three-candle reversal off the high."),
        .init(key: "three_soldiers", name: "Three White Soldiers", bias: 1, note: "Three strong closes, higher each time."),
        .init(key: "three_crows", name: "Three Black Crows", bias: -1, note: "Three weak closes, lower each time."),
        .init(key: "piercing", name: "Piercing Line", bias: 1, note: "Gap down, close back inside the body."),
        .init(key: "dark_cloud", name: "Dark Cloud Cover", bias: -1, note: "Gap up, close back inside the body."),
        .init(key: "harami_bull", name: "Bullish Harami", bias: 1, note: "Inside body after a down candle."),
        .init(key: "harami_bear", name: "Bearish Harami", bias: -1, note: "Inside body after an up candle."),
        .init(key: "tweezer_bottom", name: "Tweezer Bottom", bias: 1, note: "Two equal lows, second candle turns up."),
        .init(key: "tweezer_top", name: "Tweezer Top", bias: -1, note: "Two equal highs, second candle turns down."),
        .init(key: "double_bottom", name: "Double Bottom", bias: 1, note: "Same low tested twice, neckline broken."),
        .init(key: "double_top", name: "Double Top", bias: -1, note: "Same high tested twice, neckline broken."),
        .init(key: "bull_harami_cross", name: "Morning Doji Star", bias: 1, note: "Doji star between two real bodies."),
        .init(key: "three_methods_up", name: "Rising Three Methods", bias: 1, note: "Trend pauses inside one candle, resumes."),
        .init(key: "three_methods_down", name: "Falling Three Methods", bias: -1, note: "Downtrend pauses inside one candle, resumes."),
        .init(key: "inside_break", name: "Inside Bar Break", bias: 0, note: "Range compresses, then expands."),
        .init(key: "doji_reject", name: "Doji Rejection", bias: 0, note: "Indecision at an extreme."),
        .init(key: "hanging_man", name: "Hanging Man", bias: -1, note: "Hammer shape, but into an uptrend."),
    ]

    static func kind(_ key: String) -> PatternKind? { all.first { $0.key == key } }
}

// MARK: - Detection

struct PatternHit {
    var kind: PatternKind
    var index: Int
    var stop: Double
    var target: Double
    var score: Double
    var direction: Int { kind.bias }
}

enum PatternEngine {
    static func atr(_ cs: [Candle], _ i: Int, period: Int = 14) -> Double {
        let start = max(1, i - period + 1)
        var sum = 0.0
        var n = 0
        for k in start...i where k < cs.count {
            let prev = cs[k - 1]
            let c = cs[k]
            sum += max(c.h - c.l, abs(c.h - prev.c), abs(c.l - prev.c))
            n += 1
        }
        return n == 0 ? (cs[max(0, i)].range) : sum / Double(n)
    }

    static func ema(_ cs: [Candle], period: Int) -> [Double] {
        guard !cs.isEmpty else { return [] }
        let k = 2.0 / (Double(period) + 1)
        var out = [Double](repeating: cs[0].c, count: cs.count)
        var prev = cs[0].c
        for i in cs.indices {
            prev = cs[i].c * k + prev * (1 - k)
            out[i] = prev
        }
        return out
    }

    /// Best pattern completing at closed candle `i`. `cs` is the full series in play.
    static func detect(_ cs: [Candle], at i: Int) -> PatternHit? {
        guard i >= 4, i < cs.count else { return nil }
        let c = cs[i], p1 = cs[i - 1], p2 = cs[i - 2], p3 = cs[i - 3]
        let a = atr(cs, i)
        guard a > 0 else { return nil }

        let body = c.body
        let rng = max(c.range, a * 0.12)
        let upper = c.h - max(c.o, c.c)
        let lower = min(c.o, c.c) - c.l
        let avgBody = (0..<5).map { cs[max(0, i - $0)].body }.reduce(0, +) / 5
        let down = c.c < ema(cs, period: 10)[max(0, i - 1)] || p1.c < p2.c
        let up = c.c > ema(cs, period: 10)[max(0, i - 1)] || p1.c > p2.c

        func hit(_ key: String, _ score: Double, stopPad: Double = 0.25) -> PatternHit? {
            guard let k = PatternBook.kind(key) else { return nil }
            let stop: Double
            let entry = c.c
            if k.bias >= 0 {
                stop = min(c.l, p1.l) - a * stopPad
            } else {
                stop = max(c.h, p1.h) + a * stopPad
            }
            let risk = abs(entry - stop)
            guard risk > 0 else { return nil }
            let target = entry + (k.bias >= 0 ? 1 : -1) * risk * 2.0
            return PatternHit(kind: k, index: i, stop: stop, target: target, score: score)
        }

        // ---- single-candle reversals
        if lower > body * 1.9 && upper < body * 0.8 && body / rng < 0.42 {
            if down { return hit("hammer", 8.4) }
            if up && body > avgBody { return hit("hanging_man", 6.1) }
        }
        if upper > body * 1.9 && lower < body * 0.8 && body / rng < 0.42 {
            if up { return hit("shooting_star", 8.2) }
        }
        if body / rng < 0.12 {
            if lower > rng * 0.6 { return hit("doji_reject", 4.4, stopPad: 0.35) }
            if upper > rng * 0.6 { return hit("doji_reject", 4.0, stopPad: 0.35) }
        }

        // ---- two-candle patterns
        let bull1 = p1.c > p1.o, bull0 = c.c > c.o
        let engulf = body > p1.body * 1.08 && bull1 != bull0
        if engulf && bull0 && c.c >= p1.o && c.o <= p1.c {
            return hit("bull_engulfing", 9.1)
        }
        if engulf && !bull0 && c.c <= p1.o && c.o >= p1.c {
            return hit("bear_engulfing", 9.0)
        }
        if bull0 && body < p1.body * 0.75 && c.c > p1.o && c.o < p1.c {
            return hit("harami_bull", 7.2)
        }
        if !bull0 && body < p1.body * 0.75 && c.c < p1.o && c.o > p1.c {
            return hit("harami_bear", 7.1)
        }
        if !bull1 && bull0 && c.o < p1.c && c.c > (p1.o + p1.c) / 2 && c.c < p1.o {
            return hit("piercing", 7.8)
        }
        if bull1 && !bull0 && c.o > p1.c && c.c < (p1.o + p1.c) / 2 && c.c > p1.o {
            return hit("dark_cloud", 7.7)
        }
        if abs(c.l - p1.l) < a * 0.16 && !bull1 && bull0 && c.c > (c.h + c.l) / 2 {
            return hit("tweezer_bottom", 6.9)
        }
        if abs(c.h - p1.h) < a * 0.16 && bull1 && !bull0 && c.c < (c.h + c.l) / 2 {
            return hit("tweezer_top", 6.8)
        }
        if c.h < p1.h && c.l > p1.l {
            return hit("inside_break", 3.2, stopPad: 0.3)
        }

        // ---- three-candle patterns
        let starSmall = p1.body < p2.body * 0.5
        if p2.c < p2.o && starSmall && bull0 && c.c > (p2.o + p2.c) / 2 && c.c > p1.h {
            return hit("morning_star", 9.4)
        }
        if p2.c > p2.o && starSmall && !bull0 && c.c < (p2.o + p2.c) / 2 && c.c < p1.l {
            return hit("evening_star", 9.3)
        }
        if p2.c < p2.o && p1.body < rng * 0.16 && bull0 && c.c > (p2.o + p2.c) / 2 {
            return hit("bull_harami_cross", 8.0)
        }
        let solidUp = cs[i - 2...i].allSatisfy { $0.c > $0.o && $0.body > a * 0.35 }
        let rising = cs[i - 2].c < cs[i - 1].c && cs[i - 1].c < cs[i].c
        if solidUp && rising { return hit("three_soldiers", 8.6) }
        let solidDown = cs[i - 2...i].allSatisfy { $0.c < $0.o && $0.body > a * 0.35 }
        let falling = cs[i - 2].c > cs[i - 1].c && cs[i - 1].c > cs[i].c
        if solidDown && falling { return hit("three_crows", 8.5) }

        // ---- three methods (trend pause inside one big candle)
        if p3.c > p3.o && p3.body > a * 1.1 {
            let inside = [p2, p1, c].allSatisfy { $0.h <= p3.h && $0.l >= p3.l }
            if inside && c.c > p3.c { return hit("three_methods_up", 7.4) }
        }
        if p3.c < p3.o && p3.body > a * 1.1 {
            let inside = [p2, p1, c].allSatisfy { $0.h <= p3.h && $0.l >= p3.l }
            if inside && c.c < p3.c { return hit("three_methods_down", 7.3) }
        }

        // ---- structure: flags, double tops / bottoms
        if i >= 12 {
            let window = Array(cs[(i - 11)...i])
            // bull flag: 4+ impulse up, then 3 tight down candles, break of flag high
            let impulse = cs[(i - 7)...(i - 4)]
            let flag = cs[(i - 3)...i]
            if impulse.allSatisfy({ $0.c > $0.o }) && impulse.last!.c > impulse.first!.o * 1.006 {
                let tight = (flag.map(\.range).max() ?? 0) < a * 2.0
                if tight && c.c > flag.first!.o { return hit("bull_flag", 8.8) }
            }
            let impulseDown = cs[(i - 7)...(i - 4)]
            let flagDown = cs[(i - 3)...i]
            if impulseDown.allSatisfy({ $0.c < $0.o }) && impulseDown.last!.c < impulseDown.first!.o * 0.994 {
                let tight = (flagDown.map(\.range).max() ?? 0) < a * 2.0
                if tight && c.c < flagDown.first!.o { return hit("bear_flag", 8.7) }
            }
            // double bottom / top within the window
            let lows = window.map(\.l), highs = window.map(\.h)
            if let loIdx = lows.indices.min(by: { lows[$0] < lows[$1] }) {
                let first = lows[loIdx]
                for j in stride(from: loIdx + 3, to: window.count, by: 1) where abs(lows[j] - first) < first * 0.0025 {
                    let neck = window[loIdx...j].map(\.h).max() ?? c.c
                    if c.c > neck * 0.998 && j >= window.count - 3 {
                        return hit("double_bottom", 8.9)
                    }
                }
            }
            if let hiIdx = highs.indices.max(by: { highs[$0] < highs[$1] }) {
                let first = highs[hiIdx]
                for j in stride(from: hiIdx + 3, to: window.count, by: 1) where abs(highs[j] - first) < first * 0.0025 {
                    let neck = window[hiIdx...j].map(\.l).min() ?? c.c
                    if c.c < neck * 1.002 && j >= window.count - 3 {
                        return hit("double_top", 8.8)
                    }
                }
            }
        }
        return nil
    }

    /// All detections in a series (used by the Patterns gallery previews / bot arena).
    static func scan(_ cs: [Candle]) -> [PatternHit] {
        guard cs.count > 6 else { return [] }
        var out: [PatternHit] = []
        var lastIndex = -99
        for i in 5..<cs.count {
            guard i - lastIndex >= 3 else { continue }
            if let h = detect(cs, at: i) {
                out.append(h)
                lastIndex = i
            }
        }
        return out
    }
}

// MARK: - Bots

struct BotSpec {
    let name: String
    let strategy: String
    let icon: String
}

enum BotBook {
    static let all: [BotSpec] = [
        .init(name: "EMA CROSS", strategy: "Follows the 9/21 cross", icon: "chart.line.uptrend.xyaxis"),
        .init(name: "RSI", strategy: "Buys 30, fades 70", icon: "waveform.path.ecg"),
        .init(name: "BOLLINGER", strategy: "Fades the bands", icon: "circle.dashed"),
        .init(name: "PATTERNS", strategy: "Trades confirmed setups", icon: "square.stack.3d.up.fill"),
    ]
}

struct BotRun {
    var spec: BotSpec
    var trades: [Trade]
    var finalPnl: Double
    var winRate: Double
}
