import SwiftUI

// MARK: - Continuous feed used by the landing demos

@MainActor
final class LiveFeed: ObservableObject {
    @Published private(set) var cursor: Int
    @Published private(set) var progress: Double = 0
    let candles: [Candle]
    let ema20: [Double]
    let ema50: [Double]
    private let perCandle: Double
    private let wrapAt: Int
    private let startIndex: Int
    private var timer: Timer?
    private var last: Date?

    init(market: Market, start: Int = 520, perCandle: Double = 1.7, span: Int = 46) {
        candles = market.candles
        ema20 = PatternEngine.ema(market.candles, period: 20)
        ema50 = PatternEngine.ema(market.candles, period: 50)
        startIndex = min(max(start, span + 2), max(span + 2, market.candles.count - span - 3))
        cursor = startIndex
        self.perCandle = perCandle
        wrapAt = max(startIndex + 120, market.candles.count - 2)
    }

    func start() {
        guard timer == nil else { return }
        last = Date()
        let t = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate(); timer = nil
    }

    deinit { timer?.invalidate() }

    private func tick() {
        let now = Date()
        let dt = min(0.2, now.timeIntervalSince(last ?? now))
        last = now
        progress += dt / perCandle
        while progress >= 1 {
            progress -= 1
            cursor += 1
            if cursor >= wrapAt { cursor = startIndex }
        }
    }

    var price: Double { candles[min(cursor, candles.count - 1)].subPrice(progress) }

    var slice: [Candle] {
        let first = max(1, cursor - 45)
        var out = Array(candles[first...min(cursor, candles.count - 1)])
        if out.isEmpty { return out }
        let c = candles[min(cursor, candles.count - 1)]
        var hi = c.o, lo = c.o
        var p = 0.0
        while p <= progress {
            let px = c.subPrice(p)
            hi = max(hi, px); lo = min(lo, px)
            p += 0.06
        }
        out[out.count - 1] = Candle(t: c.t, o: c.o, h: max(hi, price), l: min(lo, price), c: price, v: c.v * progress)
        return out
    }

    var fastLine: [Double] {
        let first = max(1, cursor - 45)
        return Array(ema20[first...min(cursor, ema20.count - 1)])
    }
    var slowLine: [Double] {
        let first = max(1, cursor - 45)
        return Array(ema50[first...min(cursor, ema50.count - 1)])
    }
}

// MARK: - Landing

struct LandingView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var feed: LiveFeed

    init() {
        let m = MarketStore.shared.markets.first
        _feed = StateObject(wrappedValue: LiveFeed(market: m ?? Market(symbol: "BTC-USD", base: "BTC", quote: "USD", candles: []), start: 620))
    }

    private var market: Market? { MarketStore.shared.markets.first }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    topBar
                    hero(proxy: proxy)
                    howSection
                        .id("how")
                    setupSection
                    modesSection
                    marketsSection
                    arenaSection
                    chartsSection
                    footer
                }
            }
            .scrollIndicators(.hidden)
            .background(Ink.bg)
            .onAppear { feed.start() }
            .onDisappear { feed.stop() }
        }
    }

    // MARK: bar

    private var topBar: some View {
        HStack {
            Wordmark()
            Spacer()
            Button {
                Haptic.tap()
                withAnimation { app.screen = .hub }
            } label: {
                HStack(spacing: 6) {
                    Text("PLAY")
                        .font(Type_.label(11))
                        .tracking(1.6)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .black))
                }
                .foregroundStyle(Ink.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Chamfer(cut: 7).stroke(Ink.stroke, lineWidth: 1))
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: hero

    private func hero(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: -6) {
                Text("RIDE ANY")
                    .font(.system(size: 66, weight: .black).width(.compressed))
                    .foregroundStyle(Ink.ink)
                HStack(spacing: 0) {
                    Text("CHART")
                        .font(.system(size: 66, weight: .black).width(.compressed))
                        .foregroundStyle(Ink.orange)
                    Text(".")
                        .font(.system(size: 66, weight: .black).width(.compressed))
                        .foregroundStyle(Ink.orange)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text("Real crypto charts. Hold to ride the move,\nlet go to cash out.")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Ink.muted)
                .lineSpacing(3)
                .padding(.top, 14)

            HStack(spacing: 12) {
                Button {
                    Haptic.medium()
                    if let market { app.start(mode: .pro, market: market) }
                } label: {
                    HStack(spacing: 10) {
                        Text("PLAY")
                            .font(.system(size: 20, weight: .black).width(.compressed))
                            .tracking(2)
                        Image(systemName: "play.fill").font(.system(size: 13, weight: .black))
                    }
                    .foregroundStyle(Ink.bg)
                    .frame(width: 150, height: 58)
                    .background(Chamfer(cut: 12).fill(Ink.orange))
                    .overlay(BracketCorners(color: Ink.orange, length: 13, thickness: 2, inset: -6))
                }
                .buttonStyle(PressStyle())

                Button {
                    withAnimation { proxy.scrollTo("how", anchor: .top) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HOW TO")
                            .font(Type_.label(13))
                            .tracking(1.4)
                        Text("PLAY")
                            .font(Type_.label(13))
                            .tracking(1.4)
                    }
                    .foregroundStyle(Ink.ink)
                    .frame(width: 96, height: 58, alignment: .leading)
                    .padding(.leading, 14)
                    .background(Chamfer(cut: 10).stroke(Ink.stroke, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
                Spacer()
            }
            .padding(.top, 22)

            chartPanel
                .padding(.top, 26)

            HStack {
                Spacer()
                ScrollHint()
                Spacer()
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
        .background(
            ZStack {
                DotGrid()
                RadialGradient(colors: [Ink.orange.opacity(0.10), .clear],
                               center: .topTrailing, startRadius: 10, endRadius: 420)
            }
            .ignoresSafeArea()
        )
    }

    private var chartPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Ink.green).frame(width: 5, height: 5)
                Text((market?.base ?? "BTC") + "/USDT")
                    .font(Type_.mono(9, weight: .bold))
                    .foregroundStyle(Ink.ink)
                Text("15M")
                    .font(Type_.mono(9, weight: .bold))
                    .foregroundStyle(Ink.orange)
                Spacer()
                Text("EMA 20 · 50")
                    .font(Type_.mono(8, weight: .medium))
                    .foregroundStyle(Ink.dim)
                Text("HOLD TO RIDE")
                    .font(Type_.label(8.5))
                    .tracking(1.2)
                    .foregroundStyle(Ink.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Chamfer(cut: 3).fill(Ink.orange.opacity(0.18)))
                    .overlay(Chamfer(cut: 3).stroke(Ink.orange.opacity(0.5), lineWidth: 0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            CandleChart(candles: feed.slice,
                        ema20: feed.fastLine,
                        ema50: feed.slowLine,
                        setups: [],
                        firstIndex: 0,
                        cursorIndex: feed.slice.count - 1,
                        progress: feed.progress,
                        style: .dark,
                        livePrice: feed.price,
                        showVolume: true,
                        compact: true)
                .frame(height: 208)
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 6) {
                        Text("TAP. HOLD. LET GO.")
                            .font(Type_.mono(8, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Ink.ink.opacity(0.75))
                        Spacer()
                        Text(feed.price.priceString)
                            .font(Type_.mono(10, weight: .bold))
                            .foregroundStyle(Ink.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
        }
        .background(Chamfer(cut: 12).fill(Ink.bgLift))
        .overlay(Chamfer(cut: 12).stroke(Ink.stroke, lineWidth: 1))
        .overlay(BracketCorners(color: Ink.orange.opacity(0.55), length: 15, thickness: 1.5, inset: -3))
        .clipShape(Chamfer(cut: 12))
    }

    // MARK: how

    private var howSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "How to play", index: "01")
            Text("YOUR TURN.")
                .font(.system(size: 42, weight: .black).width(.compressed))
                .foregroundStyle(Ink.ink)
            Text("Hold to ride the move. Slide down to flip it short. Let go to cash out.")
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.muted)

            PracticeStrip(market: market)

            HStack(spacing: 12) {
                ForEach([("TAP", "open long"), ("HOLD", "ride it"), ("SLIDE", "flip short"), ("LET GO", "cash out")], id: \.0) { pair in
                    let (n, t) = pair
                    VStack(alignment: .leading, spacing: 4) {
                        Text(n)
                            .font(Type_.label(11))
                            .tracking(1.4)
                            .foregroundStyle(Ink.orange)
                        Text(t)
                            .font(.system(size: 10))
                            .foregroundStyle(Ink.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 9)
                    .background(Chamfer(cut: 6).fill(Ink.panel))
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.bgLift)
    }

    // MARK: setup

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Candle vision", index: "02")
            Text("SPOT THE\nSETUP.")
                .font(.system(size: 42, weight: .black).width(.compressed))
                .foregroundStyle(Ink.ink)
            Text("Watch a real chart print. When the game names the setup and draws its target and stop, call it: up or down.")
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.muted)

            SetupSpotCard()
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: modes

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Modes", index: "03")
            Text("PICK A MODE.")
                .font(.system(size: 42, weight: .black).width(.compressed))
                .foregroundStyle(Ink.ink)
            Text("Six ways to play the same candles.")
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.muted)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(GameMode.allCases) { mode in
                    ModeCard(mode: mode, best: nil) {
                        if let market { app.start(mode: mode, market: market) }
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.bgLift)
    }

    // MARK: markets

    private var marketsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Markets", index: "04")
            HStack(alignment: .top) {
                Text("ANY\nMARKET.")
                    .font(.system(size: 42, weight: .black).width(.compressed))
                    .foregroundStyle(Ink.ink)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("LIVE")
                        .font(Type_.label(9))
                        .tracking(1.4)
                        .foregroundStyle(Ink.green)
                    Text("\(MarketStore.shared.markets.count) RECORDED PAIRS")
                        .font(Type_.mono(8))
                        .foregroundStyle(Ink.dim)
                }
                .padding(.top, 8)
            }
            Text("A random past window of real candles. Nothing prints before you play it.")
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.muted)

            VStack(spacing: 8) {
                ForEach(MarketStore.shared.markets.prefix(6)) { m in
                    MarketRow(market: m) { app.start(mode: .pro, market: m) }
                }
            }
            .padding(.top, 2)

            Button {
                app.screen = .hub
            } label: {
                HStack {
                    Text("ALL MARKETS")
                        .font(Type_.label(11))
                        .tracking(1.6)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundStyle(Ink.ink)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: arena

    private var arenaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Bot arena", index: "05")
            Text("BOT\nARENA.")
                .font(.system(size: 42, weight: .black).width(.compressed))
                .foregroundStyle(Ink.ink)
            Text("Trade against up to nine indicator bots on one real chart. By hand, with your bot, or watch two bots fight.")
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.muted)

            VStack(spacing: 8) {
                ForEach(Array(BotBook.all.enumerated()), id: \.offset) { i, bot in
                    HStack(spacing: 10) {
                        Text(String(format: "%02d", i + 1))
                            .font(Type_.mono(9, weight: .bold))
                            .foregroundStyle(Ink.dim)
                        Image(systemName: bot.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Ink.orange)
                            .frame(width: 16)
                        Text(bot.name)
                            .font(Type_.label(12))
                            .tracking(1)
                            .foregroundStyle(Ink.ink)
                        Spacer()
                        Text(bot.strategy)
                            .font(.system(size: 9.5))
                            .foregroundStyle(Ink.muted)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Chamfer(cut: 7).fill(Ink.panel))
                }
            }
            .padding(.top, 2)

            HStack(spacing: 10) {
                Button {
                    if let market { app.start(mode: .pro, market: market, arena: true) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill").font(.system(size: 11, weight: .bold))
                        Text("VS BOTS").font(Type_.label(12)).tracking(1.4)
                    }
                    .foregroundStyle(Ink.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Chamfer(cut: 8).fill(Ink.orange))
                }
                .buttonStyle(PressStyle())

                Button {
                    app.screen = .hub
                } label: {
                    Text("BOT VS BOT")
                        .font(Type_.label(12))
                        .tracking(1.4)
                        .foregroundStyle(Ink.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.bgLift)
    }

    // MARK: charts

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Pick a chart", index: "06")
            Text("RIDE ONE\nRIGHT NOW.")
                .font(.system(size: 42, weight: .black).width(.compressed))
                .foregroundStyle(Ink.ink)
            Text("Every card is a real recorded window. Tap to play it.")
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(MarketStore.shared.markets.prefix(8).enumerated()), id: \.offset) { i, m in
                        ChartCard(market: m, start: 260 + i * 140) {
                            app.start(mode: .rush, market: m)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 34)
        .padding(.leading, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            DividerLine()
            HStack {
                Wordmark(compact: true)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Recorded charts, simulated trades")
                        .font(Type_.mono(8))
                        .foregroundStyle(Ink.dim)
                    Text("© 2026 Setup Rush")
                        .font(Type_.mono(8))
                        .foregroundStyle(Ink.dim)
                }
            }
            Button {
                app.screen = .hub
            } label: {
                HStack {
                    Text("OPEN THE DESK")
                        .font(.system(size: 22, weight: .black).width(.compressed))
                        .tracking(1.6)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .black))
                }
                .foregroundStyle(Ink.bg)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Chamfer(cut: 10).fill(Ink.orange))
            }
            .buttonStyle(PressStyle())
        }
        .padding(20)
    }
}

// MARK: - Practice strip (real hold-to-ride demo on the landing page)

struct PracticeStrip: View {
    @StateObject private var feed: LiveFeed
    @State private var holding = false
    @State private var dir = 1
    @State private var entry = 0.0
    @State private var result: Double?
    @State private var resultDir = 1

    init(market: Market?) {
        let m = market ?? Market(symbol: "BTC-USD", base: "BTC", quote: "USD", candles: [])
        _feed = StateObject(wrappedValue: LiveFeed(market: m, start: 380, perCandle: 2.2))
    }

    private var livePnl: Double {
        guard entry > 0 else { return 0 }
        return Double(dir) * (feed.price - entry) / entry * 100
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("BTC · 15M")
                    .font(Type_.mono(9, weight: .bold))
                    .foregroundStyle(Ink.paperMuted)
                Spacer()
                if holding {
                    Text(dir > 0 ? "LONG" : "SHORT")
                        .font(Type_.label(10))
                        .tracking(1.2)
                        .foregroundStyle(dir > 0 ? Color(hex: 0x18A45C) : Color(hex: 0xD2382C))
                } else if let r = result {
                    Text((r >= 0 ? "CASHED " : "STOPPED ") + String(format: "%+.2f%%", r))
                        .font(Type_.mono(10, weight: .bold))
                        .foregroundStyle(r >= 0 ? Color(hex: 0x18A45C) : Color(hex: 0xD2382C))
                } else {
                    Text("HOLD THE CHART")
                        .font(Type_.label(9))
                        .tracking(1.2)
                        .foregroundStyle(Ink.paperMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            ZStack(alignment: .topLeading) {
                CandleChart(candles: feed.slice,
                            ema20: feed.fastLine,
                            ema50: feed.slowLine,
                            firstIndex: 0,
                            cursorIndex: feed.slice.count - 1,
                            progress: feed.progress,
                            style: .paper,
                            position: holding ? Position(dir: dir, entry: entry, entryIndex: 0,
                                                          notional: 1000, leverage: 1, setupName: nil) : nil,
                            livePrice: feed.price,
                            showAxis: true,
                            showVolume: false,
                            showSetupLines: false,
                            compact: true,
                            holdDirection: holding ? dir : 0)
                    .frame(height: 150)

                if holding {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(format: "%+.2f%%", livePnl))
                            .font(.system(size: 30, weight: .black).width(.compressed))
                            .foregroundStyle(dir > 0 ? Color(hex: 0x18A45C) : Color(hex: 0xD2382C))
                        Text("SLIDE DOWN TO FLIP")
                            .font(Type_.mono(7, weight: .bold))
                            .foregroundStyle(Ink.paperMuted)
                    }
                    .padding(.leading, 10)
                    .padding(.top, 13)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !holding {
                            holding = true
                            entry = feed.price
                            dir = 1
                            result = nil
                            Haptic.tap()
                        }
                        if g.translation.height > 46 { dir = -1 }
                        else if g.translation.height < 18 { dir = 1 }
                    }
                    .onEnded { _ in
                        let pnl = livePnl
                        resultDir = dir
                        result = pnl
                        holding = false
                        Haptic.medium()
                    }
            )
        }
        .background(Chamfer(cut: 10).fill(Ink.paper))
        .clipShape(Chamfer(cut: 10))
        .overlay(Chamfer(cut: 10).stroke(Ink.stroke, lineWidth: 1))
        .onAppear { feed.start() }
        .onDisappear { feed.stop() }
    }
}

// MARK: - Setup call card

struct SetupSpotCard: View {
    @State private var answer: Int?
    private let kind = PatternBook.kind("bear_engulfing")!

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CHART 04 · 15M")
                    .font(Type_.mono(8, weight: .bold))
                    .foregroundStyle(Ink.dim)
                Spacer()
                Text("1/10")
                    .font(Type_.mono(8, weight: .bold))
                    .foregroundStyle(Ink.dim)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            ZStack(alignment: .topLeading) {
                PatternGlyph(kind: kind, tint: Ink.ink)
                    .frame(height: 96)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.name.uppercased())
                        .font(Type_.label(10))
                        .tracking(1.2)
                        .foregroundStyle(Ink.ink)
                    Text("TARGET 2R · STOP BELOW HIGH")
                        .font(Type_.mono(7, weight: .bold))
                        .foregroundStyle(Ink.orange)
                }
                .padding(9)
            }

            HStack(spacing: 8) {
                Text("CALL IT")
                    .font(Type_.label(10))
                    .tracking(1.4)
                    .foregroundStyle(Ink.muted)
                Spacer()
                ForEach([1, -1], id: \.self) { d in
                    Button {
                        answer = d
                        Haptic.medium()
                    } label: {
                        Text(d > 0 ? "UP" : "DOWN")
                            .font(Type_.label(11))
                            .tracking(1.2)
                            .foregroundStyle(answer == nil ? Ink.ink : (d == kind.bias ? Ink.bg : Ink.dim))
                            .frame(width: 74, height: 38)
                            .background(
                                Chamfer(cut: 6).fill(answer == d ? (d == kind.bias ? Ink.green : Ink.red) : Ink.panel)
                            )
                            .overlay(Chamfer(cut: 6).stroke(Ink.stroke, lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            if let a = answer {
                HStack(spacing: 6) {
                    Image(systemName: a == kind.bias ? "checkmark" : "xmark")
                        .font(.system(size: 9, weight: .black))
                    Text(a == kind.bias ? "CALLED. BEARISH ENGULFING." : "MISSED. IT WAS BEARISH.")
                        .font(Type_.label(10))
                        .tracking(1)
                    Spacer()
                }
                .foregroundStyle(a == kind.bias ? Ink.green : Ink.red)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(Chamfer(cut: 10).fill(Ink.panel))
        .overlay(Chamfer(cut: 10).stroke(Ink.stroke, lineWidth: 1))
    }
}
