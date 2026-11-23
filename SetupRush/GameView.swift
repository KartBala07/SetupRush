import SwiftUI

struct GameView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let config: GameConfig
    @StateObject private var engine: GameEngine

    @State private var holdDir = 0
    @State private var showIntro = true
    @State private var showResults = false
    @State private var recorded = false
    @State private var showQuit = false
    @State private var soundOn = true

    init(config: GameConfig) {
        self.config = config
        _engine = StateObject(wrappedValue: GameEngine(mode: config.mode, market: config.market, arena: config.arena))
    }

    private var isCallIt: Bool { config.mode == .callit }

    var body: some View {
        ZStack(alignment: .top) {
            Ink.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Color.clear.frame(height: 118)
                chartArea
                controlBar
            }

            hud
            flashOverlay
            if showIntro { introOverlay }
            if !engine.isFinished && engine.setups.isEmpty && !engine.hasTraded && !showIntro {
                hintOverlay
            }
        }
        .onAppear {
            engine.start()
            runAutoRideIfAsked()
            withAnimation(.easeInOut(duration: 0.4)) { showIntro = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                withAnimation { showIntro = false }
            }
        }
        .onDisappear { engine.stop() }
        .onChange(of: engine.isFinished) { _, finished in
            guard finished else { return }
            if !recorded {
                recorded = true
                app.record(engine.result)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                showResults = true
            }
        }
        .onChange(of: engine.flash?.id) { _, _ in
            guard engine.flash != nil else { return }
            let id = engine.flash?.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if engine.flash?.id == id { withAnimation { engine.clearFlash() } }
            }
        }
        .sheet(isPresented: $showResults) {
            ResultSheet(result: engine.result,
                        mode: config.mode,
                        onAgain: {
                            showResults = false
                            recorded = false
                            engine.restart()
                        },
                        onNewChart: {
                            showResults = false
                            recorded = false
                            dismiss()
                            let pool = MarketStore.shared.markets.filter { $0.symbol != config.market.symbol }
                            let next = pool.randomElement() ?? config.market
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                app.start(mode: config.mode, market: next, arena: config.arena)
                            }
                        },
                        onExit: {
                            showResults = false
                            dismiss()
                        })
            .presentationDetents([.large])
            .presentationBackground(Ink.bg)
            .interactiveDismissDisabled()
        }
        .alert("LEAVE THIS RUN?", isPresented: $showQuit) {
            Button("KEEP PLAYING", role: .cancel) {}
            Button("LEAVE", role: .destructive) { dismiss() }
        }
    }

    /// Debug harness: `-autoride 1` drives hold → slide-to-short → release automatically.
    private func runAutoRideIfAsked() {
        guard UserDefaults.standard.bool(forKey: "autoride") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { engine.beginHold(); holdDir = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { engine.releaseHold(); holdDir = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) { engine.beginHold() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { engine.dragged(direction: -1); holdDir = -1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 11.0) { engine.releaseHold(); holdDir = 0 }
    }

    // MARK: Chart

    private var chartArea: some View {
        ZStack {
            CandleChart(candles: engine.visibleCandles(),
                        ema20: engine.emaLine(period: 20),
                        ema50: engine.emaLine(period: 50),
                        setups: engine.setups,
                        firstIndex: engine.visibleStart,
                        cursorIndex: engine.cursor,
                        progress: 0,
                        style: .paper,
                        position: engine.position,
                        livePrice: engine.tickPrice,
                        showAxis: true,
                        showVolume: true,
                        showSetupLines: true,
                        compact: false,
                        holdDirection: holdDir)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Rectangle().fill(Ink.blue).frame(width: 5, height: 5)
                        Text("EMA " + engine.tickPrice.priceString)
                            .font(Type_.mono(8, weight: .semibold))
                            .foregroundStyle(Ink.paperMuted)
                    }
                    Text("SETUPS \(engine.setupsSeen)")
                        .font(Type_.mono(8, weight: .semibold))
                        .foregroundStyle(Ink.paperMuted)
                }
                .padding(.leading, 10)
                .padding(.top, 4)
            }
            .contentShape(Rectangle())
            .gesture(isCallIt ? nil : rideGesture)
        }
    }

    private var rideGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                if !engine.hasTraded || engine.position == nil {
                    if engine.position == nil { engine.beginHold() }
                }
                if g.translation.height > 48 {
                    holdDir = -1
                    engine.dragged(direction: -1)
                } else if g.translation.height < 14 {
                    holdDir = 1
                    engine.dragged(direction: 1)
                }
            }
            .onEnded { _ in
                engine.releaseHold()
                holdDir = 0
            }
    }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                pnlPanel
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    timerPanel
                    HStack(spacing: 6) {
                        IconChip(icon: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill") {
                            soundOn.toggle()
                        }
                        IconChip(icon: "square.and.arrow.up") {
                            if engine.hasTraded { showResults = true }
                        }
                        IconChip(icon: "line.3.horizontal") { showQuit = true }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            if !engine.arena {
                HStack(spacing: 6) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(engine.setups.last?.status == .confirmed ? Ink.green : Ink.amber)
                            .frame(width: 5, height: 5)
                        Text(config.market.name)
                            .font(Type_.mono(9, weight: .bold))
                            .foregroundStyle(Ink.paperInk)
                        Text("15M")
                            .font(Type_.mono(9, weight: .bold))
                            .foregroundStyle(Ink.paperMuted)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Chamfer(cut: 5).fill(Ink.paper.opacity(0.9)))
                    .overlay(Chamfer(cut: 5).stroke(Ink.paperGrid, lineWidth: 1))

                    if let s = engine.setups.last, s.status != .expired {
                        HStack(spacing: 4) {
                            Text(s.pattern.name.uppercased())
                                .font(Type_.label(9))
                                .tracking(1)
                                .foregroundStyle(s.direction > 0 ? Color(hex: 0x18A45C) : Color(hex: 0xD2382C))
                            Text(s.status == .confirmed ? "CONFIRMED" : "FORMING")
                                .font(Type_.mono(7.5, weight: .bold))
                                .foregroundStyle(Ink.paperMuted)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Chamfer(cut: 5).fill(Ink.paper.opacity(0.9)))
                    }
                    Spacer()
                    Text(isCallIt ? "LIVES \(max(0, 3 - engine.missedCalls))" : "\(engine.trades.count) TRADES")
                        .font(Type_.mono(8, weight: .bold))
                        .foregroundStyle(Ink.paperMuted)
                }
                .padding(.horizontal, 12)
            } else {
                HStack {
                    Text("BOT ARENA · \(BotBook.all.count) BOTS + YOU")
                        .font(Type_.mono(8, weight: .bold))
                        .foregroundStyle(Ink.paperMuted)
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private var pnlPanel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(config.mode.title)
                .font(Type_.mono(7.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Ink.muted)
            Text(displayPnl)
                .font(.system(size: 24, weight: .black).width(.condensed))
                .foregroundStyle(pnlColor)
                .contentTransition(.numericText())
            Text(isCallIt ? "\(engine.correctCalls) CALLED · \(engine.missedCalls) MISSED"
                 : "\(engine.trades.count) TRADE\(engine.trades.count == 1 ? "" : "S") · \(String(format: "%.0f", engine.mode.leverage))×")
                .font(Type_.mono(7.5, weight: .semibold))
                .foregroundStyle(Ink.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Chamfer(cut: 8).fill(Ink.bg))
        .overlay(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))
    }

    private var displayPnl: String {
        if isCallIt { return "\(engine.score) PTS" }
        return engine.pnl.money
    }
    private var pnlColor: Color {
        if isCallIt { return Ink.ink }
        return engine.pnl > 0 ? Ink.green : (engine.pnl < 0 ? Ink.red : Ink.ink)
    }

    private var timerPanel: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Text(config.mode.title)
                    .font(Type_.label(10))
                    .tracking(1)
                    .foregroundStyle(Ink.ink)
                Text(timeString)
                    .font(Type_.mono(15, weight: .bold))
                    .foregroundStyle(engine.timeLeft < 10 ? Ink.orange : Ink.ink)
                    .contentTransition(.numericText())
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Ink.stroke)
                    Rectangle().fill(engine.timeLeft < 10 ? Ink.orange : Ink.ink)
                        .frame(width: g.size.width * (engine.timeLeft / config.mode.duration))
                }
            }
            .frame(width: 128, height: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Chamfer(cut: 8).fill(Ink.bg))
        .overlay(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))
    }

    private var timeString: String {
        let t = Int(ceil(engine.timeLeft))
        return "\(t / 60):" + String(format: "%02d", t % 60)
    }

    // MARK: Bottom controls

    private var controlBar: some View {
        VStack(spacing: 10) {
            if isCallIt {
                callItPanel
            } else if engine.arena {
                arenaBoard
            } else {
                rideHint
            }

            HStack(spacing: 8) {
                ForEach([1.0, 2.0, 4.0], id: \.self) { s in
                    Button {
                        engine.setSpeed(s)
                    } label: {
                        Text("\(Int(s))×")
                            .font(Type_.mono(10, weight: .bold))
                            .foregroundStyle(engine.speed == s ? Ink.paper : Ink.paperInk)
                            .frame(width: 40, height: 28)
                            .background(Chamfer(cut: 5).fill(engine.speed == s ? Ink.paperInk : Color.clear))
                            .overlay(Chamfer(cut: 5).stroke(Ink.paperGrid, lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                }
                Spacer()
                if isCallIt {
                    Text("CALL THE DIRECTION")
                        .font(Type_.mono(8, weight: .bold))
                        .foregroundStyle(Ink.paperMuted)
                } else if let p = engine.position {
                    Text("ENTRY " + p.entry.priceString + " · " + (p.dir > 0 ? "LONG" : "SHORT"))
                        .font(Type_.mono(8, weight: .bold))
                        .foregroundStyle(Ink.paperMuted)
                } else {
                    Text("HOLD · SLIDE · RELEASE")
                        .font(Type_.mono(8, weight: .bold))
                        .foregroundStyle(Ink.paperMuted)
                }
            }
            .padding(.horizontal, 14)

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Ink.paperGrid)
                    Rectangle().fill(Ink.paperInk)
                        .frame(width: g.size.width * engine.progressFraction)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 14)
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Ink.paper)
    }

    private var rideHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Ink.bg)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Ink.amber))
            VStack(alignment: .leading, spacing: 1) {
                Text(engine.position != nil ? "RELEASE TO CASH OUT" : "HOLD TO RIDE")
                    .font(.system(size: 16, weight: .black).width(.condensed))
                    .tracking(0.8)
                    .foregroundStyle(Ink.paperInk)
                Text(engine.position != nil ? "SLIDE DOWN TO FLIP SHORT" : "SLIDE DOWN TO GO SHORT")
                    .font(Type_.mono(7.5, weight: .semibold))
                    .foregroundStyle(Ink.paperMuted)
            }
            Spacer()
            if let p = engine.position {
                Text((engine.pnl).money)
                    .font(Type_.mono(15, weight: .bold))
                    .foregroundStyle(engine.pnl >= 0 ? Color(hex: 0x18A45C) : Color(hex: 0xD2382C))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Chamfer(cut: 8).fill(Ink.paper.opacity(0.92)))
        .overlay(Chamfer(cut: 8).stroke(Ink.paperGrid, lineWidth: 1))
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private var callItPanel: some View {
        if let prompt = engine.callPrompt {
            callItPrompt(prompt)
        } else if engine.hasPendingCall {
            HStack(spacing: 8) {
                Image(systemName: engine.pendingDirection > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(engine.pendingDirection > 0 ? Color(hex: 0x18A45C) : Color(hex: 0xD2382C))
                Text((engine.pendingDirection > 0 ? "UP" : "DOWN") + " LOCKED")
                    .font(Type_.label(11))
                    .tracking(1.4)
                    .foregroundStyle(Ink.paperInk)
                Spacer()
                Text("RESOLVING…")
                    .font(Type_.mono(8, weight: .bold))
                    .foregroundStyle(Ink.paperMuted)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(Chamfer(cut: 8).fill(Ink.paper.opacity(0.94)))
            .overlay(Chamfer(cut: 8).stroke(Ink.paperGrid, lineWidth: 1))
            .padding(.horizontal, 14)
        } else {
            VStack(spacing: 8) {
                HStack {
                    Text("NO SETUP NAMED YET")
                        .font(Type_.label(10))
                        .tracking(1.2)
                        .foregroundStyle(Ink.paperInk)
                    Spacer()
                    Text("CALL THE NEXT 3 CANDLES")
                        .font(Type_.mono(7.5, weight: .bold))
                        .foregroundStyle(Ink.paperMuted)
                }
                HStack(spacing: 8) {
                    callButton("UP", Color(hex: 0x18A45C)) { engine.answerManual(1) }
                    callButton("DOWN", Color(hex: 0xD2382C)) { engine.answerManual(-1) }
                }
            }
            .padding(10)
            .background(Chamfer(cut: 8).fill(Ink.paper.opacity(0.94)))
            .overlay(Chamfer(cut: 8).stroke(Ink.paperGrid, lineWidth: 1))
            .padding(.horizontal, 14)
        }
    }

    private func callButton(_ title: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .black).width(.compressed))
                .tracking(2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Chamfer(cut: 8).fill(tint))
        }
        .buttonStyle(PressStyle())
    }

    private func callItPrompt(_ p: CallPrompt) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("CALL IT · " + p.setupName.uppercased())
                    .font(Type_.label(10))
                    .tracking(1.2)
                    .foregroundStyle(Ink.paperInk)
                Spacer()
                Text(String(format: "%.1fs", p.secondsLeft))
                    .font(Type_.mono(10, weight: .bold))
                    .foregroundStyle(Ink.orange)
            }
            HStack(spacing: 8) {
                callButton("UP", Color(hex: 0x18A45C)) { engine.answerCall(1) }
                callButton("DOWN", Color(hex: 0xD2382C)) { engine.answerCall(-1) }
            }
        }
        .padding(10)
        .background(Chamfer(cut: 8).fill(Ink.paper.opacity(0.94)))
        .overlay(Chamfer(cut: 8).stroke(Ink.paperGrid, lineWidth: 1))
        .padding(.horizontal, 14)
    }

    private var arenaBoard: some View {
        VStack(spacing: 4) {
            ForEach(Array(engine.leaderboard.enumerated()), id: \.offset) { i, row in
                HStack(spacing: 8) {
                    Text("\(i + 1)")
                        .font(Type_.mono(8, weight: .bold))
                        .foregroundStyle(Ink.paperMuted)
                        .frame(width: 12, alignment: .leading)
                    Text(row.name)
                        .font(Type_.label(10))
                        .tracking(0.8)
                        .foregroundStyle(row.you ? Ink.orange : Ink.paperInk)
                    Spacer()
                    Text(row.pnl.money)
                        .font(Type_.mono(10, weight: .bold))
                        .foregroundStyle(row.pnl >= 0 ? Color(hex: 0x18A45C) : Color(hex: 0xD2382C))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Chamfer(cut: 8).fill(Ink.paper.opacity(0.94)))
        .overlay(Chamfer(cut: 8).stroke(Ink.paperGrid, lineWidth: 1))
        .padding(.horizontal, 14)
    }

    // MARK: Overlays

    private var flashOverlay: some View {
        VStack {
            if let f = engine.flash {
                VStack(spacing: 2) {
                    Text(f.text)
                        .font(.system(size: f.big ? 44 : 24, weight: .black).width(.compressed))
                        .tracking(1.4)
                        .foregroundStyle(f.tint)
                    Text(f.detail)
                        .font(Type_.mono(8.5, weight: .bold))
                        .foregroundStyle(Ink.muted)
                        .tracking(1)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Chamfer(cut: 10).fill(Ink.bg.opacity(0.9)))
                .overlay(Chamfer(cut: 10).stroke(f.tint.opacity(0.5), lineWidth: 1))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .id(f.id)
            }
        }
        .padding(.top, 150)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private var introOverlay: some View {
        ZStack {
            Ink.bg.opacity(0.86).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text(isCallIt ? "WATCH THE\nSETUPS." : "YOUR TURN.")
                    .font(.system(size: 54, weight: .black).width(.compressed))
                    .foregroundStyle(Ink.ink)
                VStack(alignment: .leading, spacing: 10) {
                    introRow("hand.point.up.left.fill", "TAP AND HOLD", "opens a long at the live price")
                    introRow("hand.draw.fill", "SLIDE DOWN", config.mode.allowsShort ? "flips it short" : "long only in this mode")
                    introRow("hand.raised.fill", "LET GO", "cashes out and locks the P&L")
                }
                Text(isCallIt
                     ? "When the game names a setup, call the direction. Three lives."
                     : "Setups are labelled forming or confirmed. Ride the confirmed ones.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Ink.muted)
                    .padding(.top, 4)
                PrimaryButton(title: isCallIt ? "START CALLING" : "START RIDING", subtitle: "\(Int(config.mode.duration))s") {
                    withAnimation { showIntro = false }
                }
                .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onTapGesture { withAnimation { showIntro = false } }
    }

    private func introRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Ink.orange)
                .frame(width: 26, height: 26)
                .background(Chamfer(cut: 5).stroke(Ink.stroke, lineWidth: 1))
            Text(title)
                .font(Type_.label(11))
                .tracking(1.2)
                .foregroundStyle(Ink.ink)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Ink.muted)
            Spacer()
        }
    }

    private var hintOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 7) {
                Circle().stroke(Ink.paperInk, lineWidth: 1).frame(width: 10, height: 10)
                Text("WATCH FOR SETUPS")
                    .font(Type_.label(10))
                    .tracking(1.2)
                    .foregroundStyle(Ink.paperInk)
                Text("HOLD TO OPEN · RELEASE TO CASH")
                    .font(Type_.mono(7, weight: .semibold))
                    .foregroundStyle(Ink.paperMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Chamfer(cut: 6).fill(Ink.paper.opacity(0.95)))
            .overlay(Chamfer(cut: 6).stroke(Ink.paperGrid, lineWidth: 1))
            .padding(.bottom, 200)
        }
        .allowsHitTesting(false)
    }
}
