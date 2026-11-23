import SwiftUI

struct PlayHubView: View {
    @EnvironmentObject private var app: AppState
    @State private var demoTab = 0
    @State private var showInfo = false
    @State private var toast: String?

    private var markets: [Market] { MarketStore.shared.markets }
    private var defaultMarket: Market? { markets.first }

    var body: some View {
        VStack(spacing: 0) {
            header
            navTabs
            TickerRow(markets: markets)
                .padding(.top, 10)
            ScrollView {
                VStack(spacing: 18) {
                    demoSwitch
                    proCard
                    arenaCard
                    modesBlock
                    marketsBlock
                    Spacer(minLength: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
            bottomNav
        }
        .background(Ink.bg.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(Type_.label(11))
                    .tracking(1.2)
                    .foregroundStyle(Ink.bg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Chamfer(cut: 6).fill(Ink.amber))
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showInfo) { infoSheet }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                LogoMark(size: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(app.career.rank)
                        .font(.system(size: 14, weight: .black).width(.condensed))
                        .tracking(1)
                        .foregroundStyle(Ink.ink)
                    Text("LV \(app.career.level) · \(app.career.xp) XP")
                        .font(Type_.mono(8, weight: .semibold))
                        .foregroundStyle(Ink.muted)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(Chamfer(cut: 8).fill(Ink.panel))
            .overlay(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Ink.blue)
                Text("\(app.career.wicks)")
                    .font(Type_.mono(11, weight: .bold))
                    .foregroundStyle(Ink.ink)
            }
            .padding(.horizontal, 9)
            .frame(height: 42)
            .background(Chamfer(cut: 8).fill(Ink.panel))

            IconChip(icon: "gearshape.fill") { showInfo = true }
                .frame(height: 42)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: nav

    private var navTabs: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text("PLAY")
                .font(.system(size: 40, weight: .black).width(.compressed))
                .foregroundStyle(Ink.ink)
                .overlay(BracketCorners(color: Ink.orange, length: 10, thickness: 2, inset: -7))
            ForEach(["PATTERNS", "CAREER"], id: \.self) { t in
                Button {
                    Haptic.tap()
                    app.screen = (t == "PATTERNS" ? .patterns : .career)
                } label: {
                    Text(t)
                        .font(.system(size: 19, weight: .black).width(.compressed))
                        .foregroundStyle(Ink.dim)
                }
            }
            Text("SHOP")
                .font(.system(size: 19, weight: .black).width(.compressed))
                .foregroundStyle(Ink.dim.opacity(0.5))
                .onTapGesture { showToast("SHOP IS DEMO-ONLY IN THIS BUILD") }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: demo toggle

    private var demoSwitch: some View {
        HStack(spacing: 0) {
            ForEach([0, 1], id: \.self) { i in
                Button {
                    demoTab = i
                    if i == 1 { showToast("ON-CHAIN IS NOT WIRED IN THIS CLONE") }
                } label: {
                    HStack(spacing: 6) {
                        if i == 1 {
                            Image(systemName: "link")
                                .font(.system(size: 9, weight: .bold))
                        }
                        Text(i == 0 ? "DEMO" : "ON-CHAIN")
                            .font(Type_.label(11))
                            .tracking(1.4)
                    }
                    .foregroundStyle(demoTab == i ? Ink.bg : Ink.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(demoTab == i ? Ink.ink : Color.clear)
                }
            }
        }
        .padding(3)
        .background(Chamfer(cut: 8).fill(Ink.panel))
        .overlay(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))
    }

    // MARK: pro card

    private var proCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Ink.orange)
                Text("PRO")
                    .font(.system(size: 22, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(Ink.ink)
                Spacer()
                ForEach(["LONG · SHORT", "25×", "1 MIN"], id: \.self) { t in
                    Tag(text: t, tint: Ink.muted)
                }
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(defaultMarket?.name ?? "BTC/USD")
                        .font(Type_.mono(10, weight: .semibold))
                        .foregroundStyle(Ink.muted)
                    Text("BEST " + (app.career.best == 0 ? "—" : app.career.best.money))
                        .font(Type_.mono(9))
                        .foregroundStyle(Ink.dim)
                }
                Spacer()
                Text(app.career.runs == 0 ? "FIRST RUN" : "\(app.career.runs) RUNS")
                    .font(Type_.label(9))
                    .tracking(1)
                    .foregroundStyle(Ink.dim)
            }

            Button {
                if let m = defaultMarket { app.start(mode: .pro, market: m) }
            } label: {
                HStack {
                    Text("PLAY")
                        .font(.system(size: 26, weight: .black).width(.compressed))
                        .tracking(2.4)
                    Spacer()
                    Text("HOLD · FLIP · CASH")
                        .font(Type_.label(9))
                        .tracking(1.2)
                        .opacity(0.6)
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundStyle(Ink.bg)
                .padding(.horizontal, 18)
                .frame(height: 62)
                .background(Chamfer(cut: 10).fill(Ink.orange))
                .overlay(BracketCorners(color: Ink.orange, length: 12, thickness: 2, inset: -5))
            }
            .buttonStyle(PressStyle())
        }
        .padding(14)
        .background(Chamfer(cut: 12).fill(Ink.panel))
        .overlay(Chamfer(cut: 12).stroke(Ink.stroke, lineWidth: 1))
    }

    // MARK: arena

    private var arenaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Ink.orange)
                Text("BOT ARENA")
                    .font(.system(size: 20, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(Ink.ink)
                Spacer()
                Tag(text: "UP TO 9", tint: Ink.dim)
            }

            HStack(spacing: 6) {
                statPill("\(BotBook.all.count) BOTS", highlight: true)
                statPill("0 MATCHES")
                statPill("DEMO")
            }

            HStack(spacing: 8) {
                Button {
                    if let m = defaultMarket { app.start(mode: .pro, market: m, arena: true) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill").font(.system(size: 10, weight: .bold))
                        Text("VS BOTS").font(Type_.label(11)).tracking(1.2)
                    }
                    .foregroundStyle(Ink.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Chamfer(cut: 8).fill(Ink.ink))
                }
                .buttonStyle(PressStyle())

                Button {
                    if let m = defaultMarket { app.start(mode: .pro, market: m, arena: true) }
                } label: {
                    Text("BOT VS BOT")
                        .font(Type_.label(11))
                        .tracking(1.2)
                        .foregroundStyle(Ink.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(14)
        .background(Chamfer(cut: 12).fill(Ink.panel))
        .overlay(Chamfer(cut: 12).stroke(Ink.stroke, lineWidth: 1))
    }

    private func statPill(_ t: String, highlight: Bool = false) -> some View {
        Text(t)
            .font(Type_.mono(9, weight: .bold))
            .foregroundStyle(highlight ? Ink.bg : Ink.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(Chamfer(cut: 5).fill(highlight ? Ink.ink : Ink.bgLift))
            .overlay(Chamfer(cut: 5).stroke(highlight ? .clear : Ink.strokeSoft, lineWidth: 1))
    }

    // MARK: modes

    private var modesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Modes", index: "06")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(GameMode.allCases) { mode in
                    ModeCard(mode: mode, best: nil) {
                        if let m = defaultMarket { app.start(mode: mode, market: m) }
                    }
                }
            }
        }
    }

    // MARK: markets

    private var marketsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Markets", index: "\(markets.count)")
            ForEach(markets) { m in
                MarketRow(market: m) { app.start(mode: .pro, market: m) }
            }
        }
    }

    // MARK: bottom

    private var bottomNav: some View {
        HStack {
            navItem("chart.line.uptrend.xyaxis", "PLAY", active: true) {}
            navItem("square.grid.2x2.fill", "PATTERNS", active: false) { app.screen = .patterns }
            navItem("trophy.fill", "CAREER", active: false) { app.screen = .career }
            navItem("house.fill", "HOME", active: false) { app.screen = .landing }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Ink.bgLift)
        .overlay(alignment: .top) { DividerLine() }
    }

    private func navItem(_ icon: String, _ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(label)
                    .font(Type_.label(8.5))
                    .tracking(1)
            }
            .foregroundStyle(active ? Ink.orange : Ink.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    // MARK: info

    private var infoSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Wordmark()
                Spacer()
                IconChip(icon: "xmark") { showInfo = false }
            }
            Text("A native clone of setuprush.com.\nRecorded Coinbase candles (15m), simulated trades, hold-to-ride controls, Candle Vision setups and bot arena — all offline on device.")
                .font(.system(size: 12.5))
                .foregroundStyle(Ink.muted)
                .lineSpacing(3)
            DividerLine()
            ForEach([("Charts", "\(MarketStore.shared.markets.count) markets · \(MarketStore.shared.markets.reduce(0) { $0 + $1.candles.count }) candles"),
                     ("Patterns", "\(PatternBook.all.count) setups detected live"),
                     ("Modes", "Rush, Pro, Blow-Up, Call It, Sniper, Career")], id: \.0) { row in
                HStack(alignment: .top) {
                    Text(row.0.uppercased())
                        .font(Type_.label(10))
                        .tracking(1.2)
                        .foregroundStyle(Ink.muted)
                        .frame(width: 76, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Ink.ink)
                }
            }
            Spacer()
            Button {
                app.career = CareerStats()
                app.career.save()
                showInfo = false
                showToast("PROGRESS RESET")
            } label: {
                Text("RESET PROGRESS")
                    .font(Type_.label(11))
                    .tracking(1.4)
                    .foregroundStyle(Ink.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))
            }
            .buttonStyle(PressStyle())
        }
        .padding(20)
        .background(Ink.bg)
        .presentationDetents([.medium, .large])
        .presentationBackground(Ink.bg)
    }

    private func showToast(_ s: String) {
        withAnimation { toast = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - Ticker

struct TickerRow: View {
    var markets: [Market]
    @State private var offset: CGFloat = 0

    private var items: [(String, Double, Double)] {
        markets.map { ($0.base, $0.last, $0.change24h) }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 16) {
                ForEach(0..<2, id: \.self) { _ in
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        HStack(spacing: 5) {
                            Text(it.0)
                                .font(Type_.mono(9, weight: .bold))
                                .foregroundStyle(Ink.ink)
                            Text(it.1.priceString)
                                .font(Type_.mono(9))
                                .foregroundStyle(Ink.muted)
                            Text(it.2.signedPct)
                                .font(Type_.mono(9, weight: .bold))
                                .foregroundStyle(it.2 >= 0 ? Ink.green : Ink.red)
                        }
                        .fixedSize()
                    }
                }
            }
            .offset(x: offset)
            .onAppear {
                let w = CGFloat(items.count) * 128
                offset = 0
                withAnimation(.linear(duration: Double(w) / 26).repeatForever(autoreverses: false)) {
                    offset = -w
                }
            }
        }
        .frame(height: 16)
        .clipped()
        .overlay(alignment: .top) {
            LinearGradient(colors: [Ink.bg.opacity(0.95), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
        }
    }
}
