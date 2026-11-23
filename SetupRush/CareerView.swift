import SwiftUI

struct CareerView: View {
    @EnvironmentObject private var app: AppState
    @State private var showInfo = false

    private var c: CareerStats { app.career }
    private var nextXP: Int { c.level * 500 }
    private var progress: Double {
        let base = (c.level - 1) * 500
        let span = max(1, nextXP - base)
        return min(1, max(0, Double(c.xp - base) / Double(span)))
    }

    private let ladder = ["INTERN", "JUNIOR", "ANALYST", "TRADER", "DESK HEAD", "PM", "LEGEND"]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    rankCard
                    statsGrid
                    ladderCard
                    lastRunCard
                    Spacer(minLength: 20)
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .background(Ink.bg.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    app.screen = .hub
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .black))
                        Text("PLAY")
                            .font(Type_.label(10))
                            .tracking(1.2)
                    }
                    .foregroundStyle(Ink.muted)
                }
                Spacer()
                Wordmark(compact: true)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("CAREER.")
                    .font(.system(size: 40, weight: .black).width(.compressed))
                    .foregroundStyle(Ink.ink)
                Spacer()
                Text("\(c.wicks) WICKS")
                    .font(Type_.mono(9, weight: .bold))
                    .foregroundStyle(Ink.amber)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var rankCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                LogoMark(size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.rank)
                        .font(.system(size: 30, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(Ink.ink)
                    Text("LEVEL \(c.level) · \(c.xp) XP")
                        .font(Type_.mono(8.5, weight: .semibold))
                        .foregroundStyle(Ink.muted)
                }
                Spacer()
                Text("\(c.runs) RUN\(c.runs == 1 ? "" : "S")")
                    .font(Type_.mono(8, weight: .bold))
                    .foregroundStyle(Ink.dim)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Ink.stroke)
                    Rectangle().fill(Ink.orange)
                        .frame(width: g.size.width * progress)
                }
            }
            .frame(height: 5)
            Text("\(max(0, nextXP - c.xp)) XP TO \(ladder[min(ladder.count - 1, c.level)].uppercased())")
                .font(Type_.mono(7.5, weight: .bold))
                .tracking(1)
                .foregroundStyle(Ink.dim)
        }
        .padding(14)
        .background(Chamfer(cut: 12).fill(Ink.panel))
        .overlay(Chamfer(cut: 12).stroke(Ink.stroke, lineWidth: 1))
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            stat("TRADES", "\(c.trades)", Ink.ink)
            stat("WIN RATE", String(format: "%.0f%%", c.winRate), c.winRate >= 50 ? Ink.green : Ink.ink)
            stat("BEST RUN", c.best == 0 ? "—" : c.best.money, c.best > 0 ? Ink.green : Ink.ink)
            stat("NET P&L", c.netPnl == 0 ? "—" : c.netPnl.money, c.netPnl >= 0 ? Ink.green : Ink.red)
        }
    }

    private func stat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Type_.mono(7.5, weight: .bold))
                .tracking(1)
                .foregroundStyle(Ink.dim)
            Text(value)
                .font(Type_.mono(18, weight: .bold))
                .foregroundStyle(tint)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Chamfer(cut: 8).fill(Ink.panel))
        .overlay(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))
    }

    private var ladderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Ladder", index: "07")
            ForEach(Array(ladder.enumerated()), id: \.offset) { i, rank in
                HStack(spacing: 10) {
                    Text(String(format: "%02d", i + 1))
                        .font(Type_.mono(8, weight: .bold))
                        .foregroundStyle(Ink.dim)
                    Text(rank)
                        .font(Type_.label(11))
                        .tracking(1.2)
                        .foregroundStyle(i + 1 == c.level ? Ink.orange : (i + 1 < c.level ? Ink.ink : Ink.dim))
                    Spacer()
                    Text("\(max(1, i + 1) * 500) XP")
                        .font(Type_.mono(8))
                        .foregroundStyle(Ink.dim)
                    if i + 1 == c.level {
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(Ink.orange)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Chamfer(cut: 6).fill(i + 1 == c.level ? Ink.panelLift : Ink.panel))
            }
        }
    }

    private var lastRunCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Last run", index: "01")
            if c.hasRun {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(c.lastMode) · \(c.lastMarket)")
                            .font(Type_.mono(8.5, weight: .bold))
                            .foregroundStyle(Ink.muted)
                        Text(c.lastPnl.money)
                            .font(.system(size: 30, weight: .black).width(.compressed))
                            .foregroundStyle(c.lastPnl >= 0 ? Ink.green : Ink.red)
                    }
                    Spacer()
                    Sparkline(values: c.lastEquity.isEmpty ? [0, c.lastPnl] : c.lastEquity,
                              tint: c.lastPnl >= 0 ? Ink.green : Ink.red)
                        .frame(width: 110, height: 46)
                }
                HStack(spacing: 16) {
                    miniStat("TRADES", "\(c.lastTrades)")
                    miniStat("WIN", String(format: "%.0f%%", c.lastWinRate))
                    miniStat("SETUPS", "\(c.lastSetups)")
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No runs yet.")
                        .font(Type_.label(12))
                        .foregroundStyle(Ink.ink)
                    Text("Play a one-minute round and your reel lands here.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Ink.muted)
                    Button {
                        if let m = MarketStore.shared.markets.first {
                            app.start(mode: .rush, market: m)
                        }
                    } label: {
                        Text("START A RUSH")
                            .font(Type_.label(11))
                            .tracking(1.4)
                            .foregroundStyle(Ink.bg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Chamfer(cut: 6).fill(Ink.orange))
                    }
                    .buttonStyle(PressStyle())
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Chamfer(cut: 10).fill(Ink.panel))
        .overlay(Chamfer(cut: 10).stroke(Ink.stroke, lineWidth: 1))
    }

    private func miniStat(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(l)
                .font(Type_.mono(7, weight: .bold))
                .foregroundStyle(Ink.dim)
            Text(v)
                .font(Type_.mono(12, weight: .bold))
                .foregroundStyle(Ink.ink)
        }
    }
}
