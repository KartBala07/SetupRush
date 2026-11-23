import SwiftUI

struct ResultSheet: View {
    var result: RunResult
    var mode: GameMode
    var onAgain: () -> Void
    var onNewChart: () -> Void
    var onExit: () -> Void

    private var wins: Bool { result.pnl > 0 || result.correctCalls > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Wordmark(compact: true)
                    Spacer()
                    Text("REEL")
                        .font(Type_.label(9))
                        .tracking(1.6)
                        .foregroundStyle(Ink.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Chamfer(cut: 4).stroke(Ink.orange.opacity(0.5), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(mode.title) · \(result.marketName)")
                        .font(Type_.mono(9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Ink.muted)
                    Text(mode == .callit ? "\(result.correctCalls) CALLED" : result.pnl.money)
                        .font(.system(size: 62, weight: .black).width(.compressed))
                        .foregroundStyle(mode == .callit ? Ink.ink : (result.pnl >= 0 ? Ink.green : Ink.red))
                    Text(mode == .callit
                         ? "BEST STREAK \(result.bestStreak) · \(result.score) PTS"
                         : "\(result.trades.count) trades · \(String(format: "%.0f", result.winRate))% win rate · \(String(format: "%.0f", mode.leverage))× leverage")
                        .font(.system(size: 12))
                        .foregroundStyle(Ink.muted)
                }

                equityCard

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    stat("BEST TRADE", result.bestTrade == 0 ? "—" : result.bestTrade.money)
                    stat("PEAK", result.peakEquity == 0 ? "—" : "$" + String(format: "%.0f", result.peakEquity))
                    stat("SETUPS SEEN", "\(result.setupsSeen)")
                    stat("LIQUIDATED", result.liquidated ? "YES" : "NO")
                }

                if !result.trades.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "Trades", index: "\(result.trades.count)")
                        ForEach(result.trades.suffix(6)) { t in
                            HStack(spacing: 8) {
                                Text(t.direction > 0 ? "LONG" : "SHORT")
                                    .font(Type_.mono(8, weight: .bold))
                                    .foregroundStyle(t.direction > 0 ? Ink.green : Ink.red)
                                    .frame(width: 40, alignment: .leading)
                                Text(t.entry.priceString + " → " + t.exit.priceString)
                                    .font(Type_.mono(9))
                                    .foregroundStyle(Ink.muted)
                                Spacer()
                                if let s = t.setupName {
                                    Text(s.uppercased())
                                        .font(Type_.mono(7, weight: .bold))
                                        .foregroundStyle(Ink.dim)
                                        .lineLimit(1)
                                }
                                Text(t.pnl.money)
                                    .font(Type_.mono(10, weight: .bold))
                                    .foregroundStyle(t.pnl >= 0 ? Ink.green : Ink.red)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(Chamfer(cut: 6).fill(Ink.panel))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("XP AWARDED")
                        .font(Type_.mono(8, weight: .bold))
                        .foregroundStyle(Ink.dim)
                    Text("+" + "\(max(0, Int(result.pnl / 4)) + result.trades.count * 12 + result.correctCalls * 25) XP · SAVED TO CAREER")
                        .font(Type_.label(10))
                        .tracking(1)
                        .foregroundStyle(Ink.amber)
                }

                VStack(spacing: 8) {
                    PrimaryButton(title: "PLAY AGAIN", subtitle: "SAME CHART", icon: "arrow.clockwise") {
                        onAgain()
                    }
                    HStack(spacing: 8) {
                        GhostButton(title: "NEW CHART", icon: "shuffle") { onNewChart() }
                        GhostButton(title: "EXIT", icon: "xmark") { onExit() }
                    }
                    ShareLink(item: shareText) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 10, weight: .bold))
                            Text("SHARE THE REEL")
                                .font(Type_.label(10))
                                .tracking(1.2)
                        }
                        .foregroundStyle(Ink.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Ink.bg)
        .scrollIndicators(.hidden)
    }

    private var equityCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("EQUITY")
                    .font(Type_.mono(8, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Ink.muted)
                Spacer()
                Text(result.equityCurve.count > 1 ? "\(result.equityCurve.count) SAMPLES" : "NO SAMPLES")
                    .font(Type_.mono(7.5))
                    .foregroundStyle(Ink.dim)
            }
            Sparkline(values: result.equityCurve,
                      tint: result.pnl >= 0 ? Ink.green : Ink.red,
                      lineWidth: 2)
                .frame(height: 86)
                .background(
                    ZStack {
                        GridLines(color: Ink.stroke.opacity(0.5), step: 28)
                        Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1)
                    }
                )
                .clipShape(Chamfer(cut: 8))
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Type_.mono(7.5, weight: .bold))
                .tracking(1)
                .foregroundStyle(Ink.dim)
            Text(value)
                .font(Type_.mono(15, weight: .bold))
                .foregroundStyle(Ink.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Chamfer(cut: 7).fill(Ink.panel))
        .overlay(Chamfer(cut: 7).stroke(Ink.stroke, lineWidth: 1))
    }

    private var shareText: String {
        if mode == .callit {
            return "Setup Rush — \(mode.title) on \(result.marketName): \(result.correctCalls) called, \(result.score) pts."
        }
        return "Setup Rush — \(mode.title) on \(result.marketName): \(result.pnl.money) in \(result.trades.count) trades, \(String(format: "%.0f", result.winRate))% win rate."
    }
}
