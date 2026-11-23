import Foundation
import SwiftUI

// MARK: - Live objects

struct Position: Equatable {
    var dir: Int            // +1 long, -1 short
    var entry: Double
    var entryIndex: Int
    var notional: Double
    var leverage: Double
    var setupName: String?
}

struct CallPrompt: Identifiable, Equatable {
    let id = UUID()
    var setupName: String
    var biasHint: Int
    var entry: Double
    var secondsLeft: Double
}

struct Flash: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var detail: String
    var tint: Color
    var big: Bool
}

struct RunResult: Identifiable {
    let id = UUID()
    var mode: GameMode
    var marketName: String
    var pnl: Double
    var score: Int
    var trades: [Trade]
    var correctCalls: Int
    var bestStreak: Int
    var peakEquity: Double
    var equityCurve: [Double]
    var setupsSeen: Int
    var liquidated: Bool
    var startedAt: Date
    var duration: Double

    var winRate: Double {
        trades.isEmpty ? 0 : Double(trades.filter(\.win).count) / Double(trades.count) * 100
    }
    var bestTrade: Double { trades.map(\.pnl).max() ?? 0 }
}

// MARK: - Engine

@MainActor
final class GameEngine: ObservableObject {

    // Config
    let mode: GameMode
    let market: Market
    let arena: Bool
    let candles: [Candle]
    let warmup = 50
    let playCount: Int
    let startCursor: Int
    let ema20All: [Double]
    let ema50All: [Double]

    // Fast-changing state (views redraw on `version`)
    @Published private(set) var version: Int = 0
    @Published var isRunning = false
    @Published var isFinished = false
    private(set) var cursor: Int
    private(set) var progress: Double = 0
    private(set) var tickPrice: Double
    private(set) var timeLeft: Double
    private(set) var speed: Double = 1
    private(set) var equity: Double
    private(set) var peakEquity: Double
    private(set) var unrealized: Double = 0
    private(set) var viewLow: Double = 0
    private(set) var viewHigh: Double = 1

    // Slow-changing state
    @Published var position: Position?
    @Published var trades: [Trade] = []
    @Published var setups: [Setup] = []
    @Published var flash: Flash?
    @Published var callPrompt: CallPrompt?
    @Published var liquidated = false
    @Published var correctCalls = 0
    @Published var bestStreak = 0
    @Published var streak = 0
    @Published var liquidations = 0
    @Published var hasTraded = false
    @Published var showIntro = true

    // Book-keeping
    private(set) var bank: Double
    private(set) var realized: Double = 0
    private(set) var fees: Double = 0
    private(set) var equityCurve: [Double] = []
    private(set) var setupsSeen = 0
    private var currentLeverage: Double
    private var pendingCall: (dir: Int, resolveAt: Int, entry: Double)?
    private var flashTask: Task<Void, Never>?
    private var timer: Timer?
    private var lastTick: Date?
    private var candleDuration: Double = 1.5
    private var lastSetupIndex = -99
    private var cooldownUntil: Int = -1

    // Bots (arena only)
    let bots: [BotRun]
    private var botCurves: [Int: [Double]] = [:]

    // MARK: init

    init(mode: GameMode, market: Market, arena: Bool = false) {
        self.mode = mode
        self.market = market
        self.arena = arena
        self.currentLeverage = mode.leverage
        self.playCount = mode.candlesToPlay

        let need = warmup + mode.candlesToPlay + 6
        let maxStart = max(0, market.candles.count - need - 1)
        var rng = SplitMix64(seed: UInt64(Date().timeIntervalSince1970 * 1000) ^ UInt64.random(in: 0...9999))
        let start = maxStart > 0 ? Int.random(in: 0...maxStart, using: &rng) : 0
        let window = Array(market.candles[start..<min(market.candles.count, start + need)])

        self.candles = window
        self.ema20All = PatternEngine.ema(window, period: 20)
        self.ema50All = PatternEngine.ema(window, period: 50)
        self.startCursor = warmup
        self.cursor = warmup
        self.timeLeft = mode.duration
        self.bank = mode == .blowup ? 1_000 : 0
        self.equity = mode == .blowup ? 1_000 : 0
        self.peakEquity = mode == .blowup ? 1_000 : 0
        self.tickPrice = window[warmup].c
        self.bots = arena ? BotLab.run(market: market, window: window, start: warmup) : []
        updateViewRange(force: true)
        for b in bots { botCurves[b.spec.name.hashValue] = BotLab.curve(b, window: window, start: warmup) }
    }

    deinit { timer?.invalidate() }

    // MARK: Lifecycle

    func start() {
        guard timer == nil, !isFinished else { return }
        isRunning = true
        showIntro = true
        lastTick = Date()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func endRun() {
        guard !isFinished else { return }
        if let p = position { close(p, silent: true) }
        isFinished = true
        stop()
    }

    func clearFlash() { flash = nil }
    func setSpeed(_ s: Double) { speed = s; Haptic.tap() }
    func toggleSpeed() { speed = speed >= 3 ? 1 : (speed >= 2 ? 4 : 2); Haptic.tap() }

    // MARK: Tick

    private func tick() {
        guard isRunning, !isFinished else { return }
        let now = Date()
        let dt = min(0.1, now.timeIntervalSince(lastTick ?? now))
        lastTick = now
        timeLeft = max(0, timeLeft - dt)

        progress += dt / candleDuration * speed
        while progress >= 1 && cursor < candles.count - 2 {
            progress -= 1
            cursor += 1
            candleClosed()
        }
        if cursor >= candles.count - 2 && progress >= 1 { progress = 0.999 }

        tickPrice = price(at: cursor, progress: progress)
        mark()
        updateViewRange()
        sampleEquity()
        if let prompt = callPrompt {
            let next = prompt.secondsLeft - dt
            if next <= 0 {
                callPrompt = nil
            } else {
                callPrompt?.secondsLeft = next
            }
        }
        if mode == .blowup {
            currentLeverage = min(100, 25 + (mode.duration - timeLeft) / 45 * 75)
        }
        if timeLeft <= 0 { finish() }
        version &+= 1
    }

    func restart() {
        stop()
        cursor = startCursor
        progress = 0
        timeLeft = mode.duration
        bank = mode == .blowup ? 1_000 : 0
        equity = bank
        peakEquity = bank
        realized = 0
        fees = 0
        unrealized = 0
        trades = []
        setups = []
        flash = nil
        callPrompt = nil
        pendingCall = nil
        liquidated = false
        isFinished = false
        correctCalls = 0
        bestStreak = 0
        streak = 0
        missedCalls = 0
        equityCurve = []
        lastEquitySample = -Double.greatestFiniteMagnitude
        setupsSeen = 0
        lastSetupIndex = -99
        currentLeverage = mode.leverage
        tickPrice = candles[startCursor].c
        hasTraded = false
        showIntro = true
        updateViewRange(force: true)
        start()
    }

    private func finish() {
        if let p = position { close(p, silent: true) }
        isFinished = true
        stop()
        Haptic.warn()
        flash = Flash(text: "TIME", detail: "ROUND OVER", tint: Ink.amber, big: true)
    }

    /// Price along the recorded OHLC path for the printing candle.
    func price(at index: Int, progress p: Double) -> Double {
        let c = candles[min(index, candles.count - 1)]
        let legs: [(Double, Double)]
        if c.c >= c.o {
            legs = [(0, c.o), (0.20, c.l), (0.56, c.h), (0.82, c.c), (1, c.c)]
        } else {
            legs = [(0, c.o), (0.20, c.h), (0.56, c.l), (0.82, c.c), (1, c.c)]
        }
        for i in 0..<(legs.count - 1) {
            let (p0, v0) = legs[i]
            let (p1, v1) = legs[i + 1]
            if p <= p1 {
                let t = p1 == p0 ? 1 : (p - p0) / (p1 - p0)
                return v0 + (v1 - v0) * t
            }
        }
        return c.c
    }

    /// Partial OHLC of the printing candle, for rendering.
    var formingCandle: Candle {
        let c = candles[min(cursor, candles.count - 1)]
        var hi = c.o, lo = c.o
        var p = 0.0
        while p <= progress {
            let px = price(at: cursor, progress: p)
            hi = max(hi, px); lo = min(lo, px)
            p += 0.05
        }
        return Candle(t: c.t, o: c.o, h: max(hi, tickPrice), l: min(lo, tickPrice), c: tickPrice, v: c.v * progress)
    }

    // MARK: Candle close

    private func candleClosed() {
        // resolve call-it prediction
        if let pending = pendingCall, cursor >= pending.resolveAt {
            let now = candles[cursor].c
            let correct = (now - pending.entry) * Double(pending.dir) > 0
            if correct {
                correctCalls += 1
                streak += 1
                bestStreak = max(bestStreak, streak)
                flash = Flash(text: "CALLED", detail: "DIRECTION ✓", tint: Ink.green, big: true)
                Haptic.success()
            } else {
                streak = 0
                missedCalls += 1
                flash = Flash(text: "MISSED", detail: "LIVES −1", tint: Ink.red, big: true)
                Haptic.warn()
                if mode == .callit && livesLeft <= 0 { finish(); return }
            }
            pendingCall = nil
        }

        // advance / confirm / resolve setups
        for i in setups.indices {
            guard setups[i].status == .forming || setups[i].status == .confirmed else { continue }
            let close = candles[cursor].c
            let high = candles[cursor].h
            let low = candles[cursor].l
            if setups[i].status == .forming {
                if cursor - setups[i].confirmedAt > 4 {
                    setups[i].status = .expired
                    continue
                }
                if (close - setups[i].entry) * Double(setups[i].direction) > 0 {
                    setups[i].status = .confirmed
                    if mode == .callit && callPrompt == nil && pendingCall == nil {
                        setupsSeen = max(setupsSeen, 1)
                    }
                }
            } else if setups[i].status == .confirmed {
                let hitTarget = setups[i].direction > 0 ? high >= setups[i].target : low <= setups[i].target
                let hitStop = setups[i].direction > 0 ? low <= setups[i].stop : high >= setups[i].stop
                if hitTarget {
                    setups[i].status = .target
                    flash = Flash(text: "TARGET", detail: setups[i].pattern.name.uppercased(), tint: Ink.green, big: false)
                } else if hitStop {
                    setups[i].status = .stopped
                }
            }
        }

        // detect a new setup
        if cursor - lastSetupIndex >= 3, cursor >= 6 {
            if let hit = PatternEngine.detect(candles, at: cursor) {
                var dir = hit.direction
                if dir == 0 { dir = candles[cursor].isUp ? 1 : -1 }
                if mode == .rush || mode == .career { if dir < 0 { return } }
                lastSetupIndex = cursor
                setupsSeen += 1
                let label = (dir > 0 ? "BULLISH · " : "BEARISH · ") + hit.kind.name.uppercased()
                let s = Setup(pattern: hit.kind,
                              direction: dir,
                              entry: candles[cursor].c,
                              stop: hit.stop,
                              target: hit.target,
                              confirmedAt: cursor,
                              status: .forming)
                setups.append(s)
                if setups.count > 4 { setups.removeFirst(setups.count - 4) }
                if mode == .callit && callPrompt == nil && pendingCall == nil {
                    callPrompt = CallPrompt(setupName: s.pattern.name, biasHint: s.direction,
                                            entry: s.entry, secondsLeft: 6)
                }
                flash = Flash(text: s.pattern.name.uppercased(), detail: "\(label) · FORMING", tint: dir > 0 ? Ink.green : Ink.red, big: false)
            }
        }
    }

    private var livesLeft: Int { max(0, 3 - missedCalls) }
    @Published var missedCalls = 0

    // MARK: Trading

    var maxTrades: Int { mode == .sniper ? 1 : 99 }
    var canOpen: Bool { trades.count < maxTrades && !liquidated && !isFinished && timeLeft > 0 }

    var tradingEnabled: Bool { mode != .callit }

    func beginHold() {
        guard isRunning, tradingEnabled, canOpen, position == nil else { return }
        showIntro = false
        open(dir: 1)
    }

    func dragged(direction dir: Int) {
        guard canOpen else { return }
        guard let p = position else { open(dir: dir); return }
        guard p.dir != dir else { return }
        guard mode.allowsShort || dir == 1 else { return }
        close(p, silent: true)
        open(dir: dir)
        Haptic.heavy()
    }

    private func open(dir: Int) {
        let lev = mode == .blowup ? currentLeverage : mode.leverage
        let base = mode == .blowup ? max(bank, 1) : max(500, equity)
        let notional = base * lev
        let activeSetup = setups.last { $0.status == .forming || $0.status == .confirmed }
        let aligned = activeSetup.map { $0.direction == dir && cursor - $0.confirmedAt <= 4 } ?? false
        position = Position(dir: dir, entry: tickPrice, entryIndex: cursor,
                            notional: notional, leverage: lev,
                            setupName: aligned ? activeSetup?.pattern.name : nil)
        hasTraded = true
        Haptic.medium()
        flash = Flash(text: dir > 0 ? "LONG" : "SHORT",
                      detail: String(format: "%.2f× @ ", lev) + tickPrice.priceString,
                      tint: dir > 0 ? Ink.green : Ink.red, big: false)
    }

    func releaseHold() {
        guard let p = position else { return }
        close(p)
    }

    private func close(_ p: Position, silent: Bool = false) {
        let exit = tickPrice
        let pnl = p.notional * Double(p.dir) * (exit - p.entry) / max(p.entry, 0.0000001)
        let fee = p.notional * 0.0004
        realized += pnl - fee
        fees += fee
        bank += pnl - fee
        equity = bank
        peakEquity = max(peakEquity, equity)
        trades.append(Trade(direction: p.dir, entry: p.entry, exit: exit,
                            pnl: pnl - fee, atIndex: cursor, setupName: p.setupName))
        position = nil
        unrealized = 0
        if !silent {
            Haptic.success()
            flash = Flash(text: (pnl - fee) >= 0 ? "CASHED" : "STOPPED",
                          detail: (pnl - fee).money + " · " + (p.dir > 0 ? "LONG" : "SHORT"),
                          tint: (pnl - fee) >= 0 ? Ink.green : Ink.red, big: true)
        }
    }

    private func mark() {
        guard let p = position else {
            unrealized = 0
            equity = bank
            return
        }
        unrealized = p.notional * Double(p.dir) * (tickPrice - p.entry) / max(p.entry, 0.0000001)
        equity = bank + unrealized
        peakEquity = max(peakEquity, equity)
        if mode == .blowup && equity <= 0 && !liquidated {
            liquidated = true
            liquidations += 1
            bank = 0
            equity = 0
            position = nil
            unrealized = 0
            Haptic.warn()
            flash = Flash(text: "LIQUIDATED", detail: String(format: "%.0f× GONE", p.leverage), tint: Ink.red, big: true)
            finish()
        }
    }

    // MARK: Call It

    var hasPendingCall: Bool { pendingCall != nil }
    var pendingDirection: Int { pendingCall?.dir ?? 0 }

    /// Call It fallback: when no named setup is on screen, call the next three candles.
    func answerManual(_ dir: Int) {
        guard pendingCall == nil else { return }
        pendingCall = (dir, cursor + 3, tickPrice)
        Haptic.medium()
        flash = Flash(text: dir > 0 ? "UP" : "DOWN", detail: "LOCKED · 3 CANDLES", tint: dir > 0 ? Ink.green : Ink.red, big: false)
    }

    func answerCall(_ dir: Int) {
        guard let prompt = callPrompt else { return }
        pendingCall = (dir, cursor + 6, prompt.entry)
        callPrompt = nil
        Haptic.medium()
        flash = Flash(text: dir > 0 ? "UP" : "DOWN", detail: "LOCKED · 6 CANDLES", tint: dir > 0 ? Ink.green : Ink.red, big: false)
        _ = prompt
    }

    // MARK: Derived

    var pnl: Double { realized + unrealized }
    var score: Int {
        if mode == .callit { return correctCalls * 100 + bestStreak * 50 }
        return Int(pnl.rounded())
    }
    var progressFraction: Double {
        let played = Double(cursor - startCursor) + progress
        return min(1, max(0, played / Double(playCount)))
    }
    var windowCandles: Int { 46 }

    var visibleStart: Int { max(1, cursor - windowCandles + 1) }

    func visibleCandles() -> [Candle] {
        let first = max(1, cursor - windowCandles + 1)
        var out = Array(candles[first...min(cursor, candles.count - 1)])
        if !out.isEmpty { out[out.count - 1] = formingCandle }
        return out
    }

    func emaLine(period: Int) -> [Double] {
        let e = PatternEngine.ema(candles, period: period)
        let first = max(1, cursor - windowCandles + 1)
        return Array(e[first...min(cursor, candles.count - 1)])
    }

    func updateViewRange(force: Bool = false) {
        let vis = visibleCandles()
        guard !vis.isEmpty else { return }
        let lo = vis.map(\.l).min() ?? 0
        let hi = vis.map(\.h).max() ?? 1
        let pad = (hi - lo) * 0.12 + max(hi * 0.0002, 0.0000001)
        let tLo = lo - pad, tHi = hi + pad
        if force || viewHigh <= viewLow {
            viewLow = tLo; viewHigh = tHi
        } else {
            viewLow += (tLo - viewLow) * 0.16
            viewHigh += (tHi - viewHigh) * 0.16
        }
    }

    private var lastEquitySample: Double = -Double.greatestFiniteMagnitude
    func sampleEquity() {
        if abs(equity - lastEquitySample) > 0.9 || equityCurve.isEmpty {
            equityCurve.append(equity)
            lastEquitySample = equity
        }
    }

    // MARK: Bots

    func botEquity(_ run: BotRun) -> Double {
        let key = run.spec.name.hashValue
        guard let curve = botCurves[key], !curve.isEmpty else { return 0 }
        let idx = min(max(cursor - startCursor, 0), curve.count - 1)
        return curve[idx]
    }

    var leaderboard: [(name: String, pnl: Double, you: Bool)] {
        var rows = bots.map { (name: $0.spec.name, pnl: botEquity($0), you: false) }
        rows.append((name: "YOU", pnl: pnl, you: true))
        return rows.sorted { $0.pnl > $1.pnl }
    }

    var result: RunResult {
        RunResult(mode: mode, marketName: market.name, pnl: pnl, score: score,
                  trades: trades, correctCalls: correctCalls, bestStreak: bestStreak,
                  peakEquity: peakEquity, equityCurve: equityCurve.isEmpty ? [0, pnl] : equityCurve,
                  setupsSeen: setupsSeen, liquidated: liquidated,
                  startedAt: Date(), duration: mode.duration)
    }
}

// MARK: - Bot lab

enum BotLab {
    static func run(market: Market, window: [Candle], start: Int) -> [BotRun] {
        allBots(window: window, start: start)
    }

    static func allBots(window: [Candle], start: Int) -> [BotRun] {
        var out: [BotRun] = []
        let ema = emaCross(window, start: start, spec: BotBook.all[0])
        let rsi = rsiBot(window, start: start, spec: BotBook.all[1])
        let boll = bollingerBot(window, start: start, spec: BotBook.all[2])
        let pat = patternBot(window, start: start, spec: BotBook.all[3])
        out = [ema, rsi, boll, pat]
        return out
    }

    static func curve(_ run: BotRun, window: [Candle], start: Int) -> [Double] {
        var eq = 0.0
        var curve: [Double] = []
        var ti = 0
        for i in window.indices where i >= start {
            while ti < run.trades.count && run.trades[ti].atIndex == i {
                eq += run.trades[ti].pnl
                ti += 1
            }
            curve.append(eq)
        }
        return curve.isEmpty ? [0] : curve
    }

    private static func emaCross(_ cs: [Candle], start: Int, spec: BotSpec) -> BotRun {
        let e9 = PatternEngine.ema(cs, period: 9)
        let e21 = PatternEngine.ema(cs, period: 21)
        var trades: [Trade] = []
        var dir = 0
        var entry = 0.0
        var entryIdx = 0
        for i in start..<cs.count {
            let crossUp = e9[i] > e21[i] && (i == 0 || e9[i - 1] <= e21[i - 1])
            let crossDown = e9[i] < e21[i] && (i == 0 || e9[i - 1] >= e21[i - 1])
            if dir != 0 && (crossUp && dir < 0 || crossDown && dir > 0) {
                let pnl = 1000 * 10 * Double(dir) * (cs[i].c - entry) / entry
                trades.append(Trade(direction: dir, entry: entry, exit: cs[i].c, pnl: pnl, atIndex: i, setupName: nil))
                dir = 0
            }
            if dir == 0 {
                if crossUp { dir = 1; entry = cs[i].c; entryIdx = i }
                else if crossDown { dir = -1; entry = cs[i].c; entryIdx = i }
            }
        }
        if dir != 0 {
            let pnl = 1000 * 10 * Double(dir) * (cs.last!.c - entry) / entry
            trades.append(Trade(direction: dir, entry: entry, exit: cs.last!.c, pnl: pnl, atIndex: cs.count - 1, setupName: nil))
        }
        _ = entryIdx
        let p = trades.reduce(0) { $0 + $1.pnl }
        let w = trades.filter(\.win).count
        return BotRun(spec: spec, trades: trades, finalPnl: p, winRate: trades.isEmpty ? 0 : Double(w) / Double(trades.count) * 100)
    }

    private static func rsiBot(_ cs: [Candle], start: Int, spec: BotSpec) -> BotRun {
        var gains = [Double](repeating: 0, count: cs.count)
        var losses = [Double](repeating: 0, count: cs.count)
        for i in 1..<cs.count {
            let d = cs[i].c - cs[i - 1].c
            gains[i] = max(d, 0)
            losses[i] = max(-d, 0)
        }
        func rsi(_ i: Int) -> Double {
            let n = 14
            guard i > n else { return 50 }
            let g = gains[(i - n + 1)...i].reduce(0, +) / Double(n)
            let l = losses[(i - n + 1)...i].reduce(0, +) / Double(n)
            if l == 0 { return 100 }
            let rs = g / l
            return 100 - 100 / (1 + rs)
        }
        var trades: [Trade] = []
        var dir = 0, entry = 0.0
        for i in start..<cs.count {
            let r = rsi(i)
            if dir != 0 {
                let exit = (dir > 0 && r > 58) || (dir < 0 && r < 42)
                if exit {
                    let pnl = 1000 * 10 * Double(dir) * (cs[i].c - entry) / entry
                    trades.append(Trade(direction: dir, entry: entry, exit: cs[i].c, pnl: pnl, atIndex: i, setupName: nil))
                    dir = 0
                }
            }
            if dir == 0 {
                if r < 30 { dir = 1; entry = cs[i].c }
                else if r > 70 { dir = -1; entry = cs[i].c }
            }
        }
        if dir != 0 {
            let pnl = 1000 * 10 * Double(dir) * (cs.last!.c - entry) / entry
            trades.append(Trade(direction: dir, entry: entry, exit: cs.last!.c, pnl: pnl, atIndex: cs.count - 1, setupName: nil))
        }
        let p = trades.reduce(0) { $0 + $1.pnl }
        let w = trades.filter(\.win).count
        return BotRun(spec: spec, trades: trades, finalPnl: p, winRate: trades.isEmpty ? 0 : Double(w) / Double(trades.count) * 100)
    }

    private static func bollingerBot(_ cs: [Candle], start: Int, spec: BotSpec) -> BotRun {
        func band(_ i: Int) -> (mid: Double, up: Double, lo: Double) {
            let n = 20
            let s = max(0, i - n + 1)
            let slice = cs[s...i].map(\.c)
            let mid = slice.reduce(0, +) / Double(slice.count)
            let varsum = slice.reduce(0) { $0 + pow($1 - mid, 2) } / Double(slice.count)
            let sd = sqrt(varsum)
            return (mid, mid + sd * 2, mid - sd * 2)
        }
        var trades: [Trade] = []
        var dir = 0, entry = 0.0, mid = 0.0
        for i in start..<cs.count {
            guard i > 21 else { continue }
            let b = band(i)
            if dir != 0 {
                let exit = (dir > 0 && cs[i].c > mid) || (dir < 0 && cs[i].c < mid)
                if exit {
                    let pnl = 1000 * 10 * Double(dir) * (cs[i].c - entry) / entry
                    trades.append(Trade(direction: dir, entry: entry, exit: cs[i].c, pnl: pnl, atIndex: i, setupName: nil))
                    dir = 0
                }
            }
            if dir == 0 {
                if cs[i].c < b.lo { dir = 1; entry = cs[i].c; mid = b.mid }
                else if cs[i].c > b.up { dir = -1; entry = cs[i].c; mid = b.mid }
            }
        }
        if dir != 0 {
            let pnl = 1000 * 10 * Double(dir) * (cs.last!.c - entry) / entry
            trades.append(Trade(direction: dir, entry: entry, exit: cs.last!.c, pnl: pnl, atIndex: cs.count - 1, setupName: nil))
        }
        let p = trades.reduce(0) { $0 + $1.pnl }
        let w = trades.filter(\.win).count
        return BotRun(spec: spec, trades: trades, finalPnl: p, winRate: trades.isEmpty ? 0 : Double(w) / Double(trades.count) * 100)
    }

    private static func patternBot(_ cs: [Candle], start: Int, spec: BotSpec) -> BotRun {
        let hits = PatternEngine.scan(cs).filter { $0.index >= start }
        var trades: [Trade] = []
        for h in hits {
            let exitIdx = min(h.index + 6, cs.count - 1)
            let entry = cs[h.index].c
            let exit = cs[exitIdx].c
            let pnl = 1000 * 10 * Double(h.direction) * (exit - entry) / entry
            trades.append(Trade(direction: h.direction, entry: entry, exit: exit, pnl: pnl, atIndex: exitIdx, setupName: h.kind.name))
        }
        let p = trades.reduce(0) { $0 + $1.pnl }
        let w = trades.filter(\.win).count
        return BotRun(spec: spec, trades: trades, finalPnl: p, winRate: trades.isEmpty ? 0 : Double(w) / Double(trades.count) * 100)
    }
}
