import SwiftUI

// MARK: - Brand mark

struct LogoMark: View {
    var size: CGFloat = 26
    var tint: Color = Ink.orange

    var body: some View {
        Canvas { ctx, s in
            let w = s.width
            let r = CGRect(x: w * 0.18, y: w * 0.16, width: w * 0.64, height: w * 0.62)
            let arc = Path { p in
                p.addArc(center: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2,
                         startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            }
            ctx.stroke(arc, with: .color(tint), style: StrokeStyle(lineWidth: w * 0.13, lineCap: .round))
            var legs = Path()
            legs.move(to: CGPoint(x: w * 0.2, y: w * 0.52)); legs.addLine(to: CGPoint(x: w * 0.2, y: w * 0.82))
            legs.move(to: CGPoint(x: w * 0.8, y: w * 0.52)); legs.addLine(to: CGPoint(x: w * 0.8, y: w * 0.82))
            ctx.stroke(legs, with: .color(tint), style: StrokeStyle(lineWidth: w * 0.13, lineCap: .round))
            var candle = Path()
            candle.move(to: CGPoint(x: w * 0.5, y: w * 0.2)); candle.addLine(to: CGPoint(x: w * 0.5, y: w * 0.78))
            ctx.stroke(candle, with: .color(.white), lineWidth: w * 0.07)
            let body = CGRect(x: w * 0.38, y: w * 0.36, width: w * 0.24, height: w * 0.22)
            ctx.fill(Path(roundedRect: body, cornerRadius: w * 0.03), with: .color(.white))
        }
        .frame(width: size, height: size)
    }
}

struct Wordmark: View {
    var compact: Bool = false
    var body: some View {
        HStack(spacing: 9) {
            LogoMark(size: compact ? 22 : 26)
            Text("SETUP RUSH")
                .font(.system(size: compact ? 15 : 17, weight: .black).width(.condensed))
                .tracking(1.4)
                .foregroundStyle(Ink.ink)
        }
    }
}

// MARK: - Market row

struct MarketRow: View {
    var market: Market
    var onRide: () -> Void

    var body: some View {
        Button(action: onRide) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(market.base)
                            .font(.system(size: 16, weight: .heavy).width(.condensed))
                            .foregroundStyle(Ink.ink)
                        Tag(text: "15M", tint: Ink.dim)
                    }
                    Text(market.last.priceString)
                        .font(Type_.mono(11))
                        .foregroundStyle(Ink.muted)
                }
                Spacer(minLength: 4)
                Sparkline(values: market.spark,
                          tint: market.change24h >= 0 ? Ink.green : Ink.red)
                    .frame(width: 62, height: 26)
                Text(market.change24h.signedPct)
                    .font(Type_.mono(11, weight: .bold))
                    .foregroundStyle(market.change24h >= 0 ? Ink.green : Ink.red)
                    .frame(width: 54, alignment: .trailing)
                Text("RIDE IT")
                    .font(Type_.label(9))
                    .tracking(1)
                    .foregroundStyle(Ink.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Chamfer(cut: 4).stroke(Ink.stroke, lineWidth: 1))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Chamfer(cut: 8).fill(Ink.panel))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Mode card

struct ModeCard: View {
    var mode: GameMode
    var best: Double?
    var onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Ink.orange)
                    Spacer()
                    if let best, best != 0 {
                        Text("BEST " + best.money)
                            .font(Type_.mono(8, weight: .bold))
                            .foregroundStyle(Ink.dim)
                    }
                }
                Spacer(minLength: 6)
                Text(mode.title)
                    .font(.system(size: 26, weight: .black).width(.compressed))
                    .tracking(0.6)
                    .foregroundStyle(Ink.ink)
                Text(mode.tagline)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Ink.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Text(mode.accent)
                        .font(Type_.mono(8, weight: .semibold))
                        .foregroundStyle(Ink.dim)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Ink.orange)
                }
            }
            .padding(12)
            .frame(height: 132, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background(Chamfer(cut: 10).fill(Ink.panel))
            .overlay(Chamfer(cut: 10).stroke(Ink.stroke, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Chart picker card

struct ChartCard: View {
    var market: Market
    var start: Int
    var window: Int = 40
    var onRide: () -> Void

    private var slice: [Candle] {
        let s = min(max(start, 0), max(0, market.candles.count - window - 1))
        return Array(market.candles[s..<min(market.candles.count, s + window)])
    }
    private var change: Double {
        guard let f = slice.first, let l = slice.last, f.c > 0 else { return 0 }
        return (l.c - f.c) / f.c * 100
    }

    var body: some View {
        Button(action: onRide) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(market.base)
                        .font(.system(size: 13, weight: .black).width(.condensed))
                        .foregroundStyle(Ink.ink)
                    Text(change.signedPct)
                        .font(Type_.mono(9, weight: .bold))
                        .foregroundStyle(change >= 0 ? Ink.green : Ink.red)
                    Spacer()
                }
                CandleChart(candles: slice,
                            ema20: PatternEngine.ema(slice, period: 20),
                            ema50: [],
                            firstIndex: 0,
                            cursorIndex: slice.count - 1,
                            style: .dark,
                            showAxis: false,
                            showVolume: false,
                            showSetupLines: false,
                            compact: true)
                    .frame(height: 48)
                Text("RIDE IT")
                    .font(Type_.label(9))
                    .tracking(1.2)
                    .foregroundStyle(Ink.orange)
            }
            .padding(10)
            .frame(width: 132, height: 108)
            .background(Chamfer(cut: 8).fill(Ink.panel))
            .overlay(Chamfer(cut: 8).stroke(Ink.stroke, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Small chrome

struct IconChip: View {
    var icon: String
    var tint: Color = Ink.ink
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Chamfer(cut: 6).fill(Ink.panel))
                .overlay(Chamfer(cut: 6).stroke(Ink.stroke, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle().fill(Ink.strokeSoft).frame(height: 1)
    }
}

struct ScrollHint: View {
    var text: String = "SCROLL DOWN"
    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Ink.orange).frame(width: 14, height: 2)
            Text(text)
                .font(Type_.label(9))
                .tracking(2)
                .foregroundStyle(Ink.muted)
            Image(systemName: "arrow.down")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(Ink.orange)
        }
    }
}
