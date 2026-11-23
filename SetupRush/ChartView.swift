import SwiftUI

// MARK: - Style

struct ChartStyle {
    var bg: Color = Ink.paper
    var grid: Color = Ink.paperGrid.opacity(0.85)
    var axis: Color = Ink.paperMuted
    var up: Color = Ink.paperInk
    var down: Color = Color(hex: 0xF9F7F0)
    var downStroke: Color = Ink.paperInk
    var wick: Color = Ink.paperInk
    var emaFast: Color = Color(hex: 0x3F6FE0)
    var emaSlow: Color = Color(hex: 0xB08A5A)
    var accent: Color = Ink.paperInk
    var label: Color = Ink.paperInk
    var live: Color = Color(hex: 0xE0372A)

    static let paper = ChartStyle()

    static let dark = ChartStyle(bg: Color(hex: 0x0B0B0C),
                                grid: Color.white.opacity(0.055),
                                axis: Color.white.opacity(0.35),
                                up: Color(hex: 0xF2F0EA),
                                down: Color(hex: 0xFF4B3E),
                                downStroke: Color(hex: 0xFF4B3E),
                                wick: Color(hex: 0xD9D6CD),
                                emaFast: Color(hex: 0x6FA8FF),
                                emaSlow: Color(hex: 0x8E8E96),
                                accent: Ink.orange,
                                label: Ink.ink,
                                live: Ink.orange)
}

// MARK: - Chart

struct CandleChart: View {
    var candles: [Candle]
    var ema20: [Double]
    var ema50: [Double]
    var setups: [Setup] = []
    var firstIndex: Int            // absolute index of candles[0]
    var cursorIndex: Int
    var progress: Double = 0
    var style: ChartStyle = .paper
    var position: Position? = nil
    var livePrice: Double? = nil
    var showAxis: Bool = true
    var showVolume: Bool = true
    var showSetupLines: Bool = true
    var compact: Bool = false
    var holdDirection: Int = 0

    private let axisW: CGFloat = 54

    var body: some View {
        Canvas { ctx, size in
            draw(ctx: &ctx, size: size)
        }
        .background(style.bg)
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize) {
        guard !candles.isEmpty else { return }
        let axisW: CGFloat = showAxis ? self.axisW : 4
        let plotW = max(10, size.width - axisW)
        let volH = showVolume ? size.height * (compact ? 0.16 : 0.14) : 0
        let plotH = size.height - volH - 8
        let top: CGFloat = compact ? 4 : 8

        let count = candles.count
        let step = plotW / CGFloat(max(count, 1))
        let bodyW = max(2.0, min(step * 0.62, 12.0))

        // Range (includes setups + position)
        var lo = candles.map(\.l).min() ?? 0
        var hi = candles.map(\.h).max() ?? 1
        for s in setups where s.status != .expired {
            lo = min(lo, s.stop, s.target); hi = max(hi, s.stop, s.target)
        }
        if let p = position { lo = min(lo, p.entry); hi = max(hi, p.entry) }
        if let lp = livePrice { lo = min(lo, lp); hi = max(hi, lp) }
        let pad = (hi - lo) * 0.14 + max(hi * 0.00025, 0.0000001)
        lo -= pad; hi += pad
        let span = max(hi - lo, 0.0000001)

        func y(_ price: Double) -> CGFloat {
            top + CGFloat((hi - price) / span) * (plotH - top)
        }
        func x(_ absolute: Int) -> CGFloat {
            CGFloat(absolute - firstIndex) * step + step / 2 - CGFloat(progress) * step
        }

        // Grid
        var grid = Path()
        let ticks = 4
        for k in 0...ticks {
            let yy = top + (plotH - top) * CGFloat(k) / CGFloat(ticks)
            grid.move(to: CGPoint(x: 0, y: yy))
            grid.addLine(to: CGPoint(x: plotW, y: yy))
        }
        ctx.stroke(grid, with: .color(style.grid), lineWidth: 0.6)

        // Volume
        if showVolume {
            let maxV = candles.map(\.v).max() ?? 1
            for (i, c) in candles.enumerated() {
                let h = CGFloat(c.v / max(1, maxV)) * volH
                let r = CGRect(x: x(i + firstIndex) - bodyW / 2, y: size.height - h, width: bodyW, height: h)
                ctx.fill(Path(r), with: .color((c.isUp ? style.up : style.live).opacity(0.13)))
            }
        }

        // EMA lines
        func emaPath(_ vals: [Double]) -> Path {
            var p = Path()
            var started = false
            for (i, v) in vals.enumerated() {
                let pt = CGPoint(x: x(i + firstIndex), y: y(v))
                if !started { p.move(to: pt); started = true } else { p.addLine(to: pt) }
            }
            return p
        }
        if ema50.count == count {
            ctx.stroke(emaPath(ema50), with: .color(style.emaSlow.opacity(0.85)), lineWidth: 1.2)
        }
        if ema20.count == count {
            ctx.stroke(emaPath(ema20), with: .color(style.emaFast.opacity(0.9)), lineWidth: 1.3)
        }

        // Candles
        for (i, c) in candles.enumerated() {
            let cx = x(i + firstIndex)
            guard cx > -step, cx < plotW + step else { continue }
            let up = c.c >= c.o
            var wick = Path()
            wick.move(to: CGPoint(x: cx, y: y(c.h)))
            wick.addLine(to: CGPoint(x: cx, y: y(c.l)))
            ctx.stroke(wick, with: .color(style.wick.opacity(0.75)), lineWidth: 1)

            let yo = y(c.o), yc = y(c.c)
            let rect = CGRect(x: cx - bodyW / 2, y: min(yo, yc), width: bodyW, height: max(1.4, abs(yo - yc)))
            if up {
                ctx.fill(Path(rect), with: .color(style.up))
            } else {
                ctx.fill(Path(rect), with: .color(style.down))
                ctx.stroke(Path(rect), with: .color(style.downStroke.opacity(0.55)), lineWidth: 1)
            }
        }

        // Setups
        if showSetupLines, let s = setups.last(where: { $0.status != .expired || $0.status == .target }) {
            let isBull = s.direction > 0
            let tint = isBull ? Color(hex: 0x18A45C) : Color(hex: 0xE0372A)
            let tgtColor = Color(hex: 0x18A45C)
            let stopColor = Color(hex: 0xD2382C)
            let anchorX = x(s.confirmedAt)
            let labelW: CGFloat = 148

            func level(_ v: Double, _ color: Color, _ text: String, dash: Bool = true) {
                var p = Path()
                p.move(to: CGPoint(x: max(0, anchorX - step * 3), y: y(v)))
                p.addLine(to: CGPoint(x: plotW - 4, y: y(v)))
                ctx.stroke(p, with: .color(color.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 1, dash: dash ? [4, 3] : []))
                let tag = Text(text)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                ctx.draw(tag, at: CGPoint(x: plotW - 6, y: y(v) - 9), anchor: .trailing)
            }

            level(s.entry, tint, "ENTRY " + s.entry.priceString)
            level(s.stop, stopColor, "STOP " + s.stop.priceString)
            level(s.target, tgtColor, "TGT " + s.target.priceString + " · " + String(format: "%.1fR", s.rMultiple))

            // Callout near the setup
            let status = s.status == .confirmed ? "CONFIRMED" : (s.status == .target ? "TARGET HIT" : (s.status == .stopped ? "STOPPED" : "FORMING"))
            let bias = isBull ? "BULLISH" : "BEARISH"
            let boxW = labelW + 16
            let boxH: CGFloat = 30
            let bx = min(max(anchorX + 6, 2), plotW - boxW - 2)
            let by: CGFloat = top + 3
            let box = CGRect(x: bx, y: by, width: boxW, height: boxH)
            ctx.fill(Path(roundedRect: box, cornerRadius: 3), with: .color(style.bg.opacity(0.94)))
            ctx.stroke(Path(roundedRect: box, cornerRadius: 3), with: .color(tint.opacity(0.9)), lineWidth: 1)
            var leader = Path()
            leader.move(to: CGPoint(x: bx + 10, y: by + boxH))
            leader.addLine(to: CGPoint(x: bx + 10, y: min(y(s.entry), plotH - 4)))
            leader.move(to: CGPoint(x: bx + 10, y: min(y(s.entry), plotH - 4)))
            leader.addLine(to: CGPoint(x: anchorX, y: min(y(s.entry), plotH - 4)))
            ctx.stroke(leader, with: .color(tint.opacity(0.6)), lineWidth: 0.8)

            ctx.draw(Text(s.pattern.name.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(style.label),
                     at: CGPoint(x: bx + 7, y: by + 8), anchor: .leading)
            ctx.draw(Text("\(bias) · \(status)")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(tint),
                     at: CGPoint(x: bx + 7, y: by + 19), anchor: .leading)
        }

        // Position
        if let p = position {
            let lineY = y(p.entry)
            var pl = Path()
            pl.move(to: CGPoint(x: 0, y: lineY)); pl.addLine(to: CGPoint(x: plotW, y: lineY))
            ctx.stroke(pl, with: .color(style.label.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            let tint = p.dir > 0 ? Color(hex: 0x18A45C) : Color(hex: 0xD2382C)
            let markR = CGRect(x: 0, y: lineY - 9, width: 76, height: 18)
            ctx.fill(Path(roundedRect: markR, cornerRadius: 3), with: .color(tint))
            ctx.draw(Text((p.dir > 0 ? "LONG " : "SHORT ") + String(format: "%.0f×", p.leverage))
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white),
                     at: CGPoint(x: 6, y: lineY), anchor: .leading)
        }

        // Live price
        if let lp = livePrice, showAxis {
            let ly = y(lp)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: ly)); path.addLine(to: CGPoint(x: plotW, y: ly))
            ctx.stroke(path, with: .color(style.live.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            let r = CGRect(x: plotW + 1, y: ly - 8, width: axisW - 2, height: 16)
            ctx.fill(Path(r), with: .color(style.live))
            ctx.draw(Text(lp.priceString)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white),
                     at: CGPoint(x: plotW + axisW / 2, y: ly), anchor: .center)
        }

        // Axis labels
        if showAxis {
            for k in 0...ticks {
                let v = hi - span * Double(k) / Double(ticks)
                let yy = top + (plotH - top) * CGFloat(k) / CGFloat(ticks)
                ctx.draw(Text(v.priceString)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(style.axis),
                         at: CGPoint(x: plotW + axisW - 3, y: yy + 7), anchor: .trailing)
            }
            // time labels
            if candles.count > 4 {
                for k in 0..<4 {
                    let i = Int(Double(candles.count - 1) * Double(k) / 3.0)
                    let c = candles[min(i, candles.count - 1)]
                    let d = Date(timeIntervalSince1970: c.t)
                    let f = DateFormatter()
                    f.dateFormat = k == 0 ? "MMM d" : "HH:mm"
                    ctx.draw(Text(f.string(from: d))
                                .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                                .foregroundColor(style.axis),
                             at: CGPoint(x: x(i + firstIndex), y: size.height - 6), anchor: .center)
                }
            }
        }

        // Hold state tint
        if holdDirection != 0 {
            let tint = holdDirection > 0 ? Color(hex: 0x18A45C) : Color(hex: 0xD2382C)
            ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                     with: .color(tint.opacity(0.07)))
            ctx.stroke(Path(CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)),
                       with: .color(tint.opacity(0.5)), lineWidth: 1.5)
            ctx.draw(Text(holdDirection > 0 ? "RIDING LONG" : "RIDING SHORT")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(tint),
                     at: CGPoint(x: 12, y: size.height - 26), anchor: .leading)
        }
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    var values: [Double]
    var tint: Color = Ink.green
    var lineWidth: CGFloat = 1.6

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1, let lo = values.min(), let hi = values.max(), hi > lo else { return }
            var p = Path()
            for (i, v) in values.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
                let y = size.height * (1 - CGFloat((v - lo) / (hi - lo)))
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            var fill = p
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            ctx.fill(fill, with: .linearGradient(Gradient(colors: [tint.opacity(0.28), tint.opacity(0)]),
                                                 startPoint: .zero,
                                                 endPoint: CGPoint(x: 0, y: size.height)))
            ctx.stroke(p, with: .color(tint), lineWidth: lineWidth)
        }
    }
}

// MARK: - Mini pattern illustration

struct PatternGlyph: View {
    var kind: PatternKind
    var tint: Color = Ink.ink
    var body: some View {
        Canvas { ctx, size in
            let bars = PatternGlyph.bars(for: kind)
            guard !bars.isEmpty else { return }
            let step = size.width / CGFloat(bars.count + 1)
            let mid = size.height / 2
            for (i, b) in bars.enumerated() {
                let cx = step * (CGFloat(i) + 1)
                let hh = (b.h - b.l) * size.height * 0.5
                let yo = mid - b.o * size.height * 0.42
                let yc = mid - b.c * size.height * 0.42
                var wick = Path()
                wick.move(to: CGPoint(x: cx, y: mid - hh))
                wick.addLine(to: CGPoint(x: cx, y: mid + hh))
                ctx.stroke(wick, with: .color(tint.opacity(0.55)), lineWidth: 1)
                let up = b.c >= b.o
                let r = CGRect(x: cx - step * 0.26, y: min(yo, yc), width: step * 0.52, height: max(1.5, abs(yo - yc)))
                if up {
                    ctx.fill(Path(r), with: .color(tint.opacity(0.9)))
                } else {
                    ctx.fill(Path(r), with: .color(Ink.bg.opacity(0.9)))
                    ctx.stroke(Path(r), with: .color(tint.opacity(0.75)), lineWidth: 1)
                }
            }
        }
    }

    struct Bar { var o: Double; var h: Double; var l: Double; var c: Double }

    /// Stylised candle templates so each pattern reads at a glance.
    static func bars(for k: PatternKind) -> [Bar] {
        let t: [Bar]
        switch k.key {
        case "hammer":
            t = [Bar(o: 0.2, h: 0.3, l: -0.5, c: 0.15), Bar(o: 0.0, h: 0.15, l: -0.95, c: 0.1)]
        case "shooting_star":
            t = [Bar(o: -0.1, h: 0.2, l: -0.3, c: 0.0), Bar(o: 0.0, h: 0.95, l: -0.15, c: -0.9)]
        case "bull_engulfing":
            t = [Bar(o: 0.3, h: 0.4, l: 0.15, c: 0.1), Bar(o: 0.05, h: 0.6, l: -0.1, c: 0.5)]
        case "bear_engulfing":
            t = [Bar(o: 0.0, h: 0.25, l: -0.15, c: 0.2), Bar(o: 0.35, h: 0.45, l: -0.1, c: -0.2)]
        case "morning_star", "bull_harami_cross":
            t = [Bar(o: 0.5, h: 0.55, l: -0.1, c: -0.05), Bar(o: -0.2, h: -0.1, l: -0.35, c: -0.22), Bar(o: 0.0, h: 0.6, l: -0.05, c: 0.55)]
        case "evening_star":
            t = [Bar(o: -0.5, h: 0.05, l: -0.55, c: 0.05), Bar(o: 0.2, h: 0.35, l: 0.15, c: 0.22), Bar(o: 0.0, h: 0.55, l: -0.6, c: -0.5)]
        case "three_soldiers":
            t = [Bar(o: 0.0, h: 0.25, l: -0.05, c: 0.2), Bar(o: 0.2, h: 0.45, l: 0.15, c: 0.4), Bar(o: 0.4, h: 0.7, l: 0.35, c: 0.65)]
        case "three_crows":
            t = [Bar(o: 0.4, h: 0.55, l: 0.3, c: 0.15), Bar(o: 0.2, h: 0.3, l: 0.0, c: -0.05), Bar(o: 0.0, h: 0.1, l: -0.3, c: -0.25)]
        case "piercing":
            t = [Bar(o: 0.4, h: 0.45, l: -0.4, c: -0.3), Bar(o: -0.45, h: -0.05, l: -0.55, c: 0.15)]
        case "dark_cloud":
            t = [Bar(o: -0.3, h: 0.4, l: -0.35, c: 0.3), Bar(o: 0.45, h: 0.55, l: 0.0, c: -0.1)]
        case "harami_bull":
            t = [Bar(o: 0.4, h: 0.45, l: -0.3, c: -0.25), Bar(o: -0.1, h: 0.05, l: -0.2, c: 0.02)]
        case "harami_bear":
            t = [Bar(o: -0.25, h: 0.3, l: -0.3, c: 0.35), Bar(o: 0.05, h: 0.2, l: 0.0, c: 0.1)]
        case "tweezer_bottom":
            t = [Bar(o: 0.2, h: 0.25, l: -0.6, c: -0.55), Bar(o: -0.5, h: -0.1, l: -0.62, c: 0.1)]
        case "tweezer_top":
            t = [Bar(o: -0.2, h: 0.6, l: -0.25, c: 0.55), Bar(o: 0.5, h: 0.62, l: 0.0, c: -0.1)]
        case "double_bottom":
            t = [Bar(o: 0.3, h: 0.35, l: -0.55, c: -0.5), Bar(o: -0.4, h: 0.0, l: -0.5, c: 0.0), Bar(o: 0.0, h: 0.2, l: -0.05, c: 0.1), Bar(o: 0.1, h: 0.15, l: -0.55, c: -0.5), Bar(o: -0.4, h: 0.45, l: -0.45, c: 0.4)]
        case "double_top":
            t = [Bar(o: -0.3, h: 0.55, l: -0.35, c: 0.5), Bar(o: 0.4, h: 0.5, l: 0.0, c: 0.0), Bar(o: 0.0, h: 0.2, l: -0.15, c: 0.15), Bar(o: 0.1, h: 0.55, l: 0.05, c: 0.5), Bar(o: 0.45, h: 0.5, l: -0.45, c: -0.4)]
        case "bull_flag":
            t = [Bar(o: -0.4, h: 0.6, l: -0.45, c: 0.55), Bar(o: 0.55, h: 0.6, l: 0.3, c: 0.35), Bar(o: 0.35, h: 0.38, l: 0.2, c: 0.22), Bar(o: 0.22, h: 0.3, l: 0.15, c: 0.25), Bar(o: 0.25, h: 0.62, l: 0.15, c: 0.58)]
        case "bear_flag":
            t = [Bar(o: 0.5, h: 0.55, l: -0.55, c: -0.5), Bar(o: -0.5, h: -0.25, l: -0.55, c: -0.3), Bar(o: -0.3, h: -0.15, l: -0.32, c: -0.2), Bar(o: -0.2, h: -0.1, l: -0.25, c: -0.15), Bar(o: -0.15, h: -0.1, l: -0.6, c: -0.55)]
        case "hanging_man":
            t = [Bar(o: -0.5, h: -0.3, l: -0.55, c: -0.35), Bar(o: 0.0, h: 0.15, l: -0.9, c: 0.05)]
        case "doji_reject":
            t = [Bar(o: 0.2, h: 0.25, l: -0.4, c: 0.19), Bar(o: 0.0, h: 0.35, l: -0.55, c: 0.0)]
        case "inside_break":
            t = [Bar(o: -0.2, h: 0.4, l: -0.4, c: 0.35), Bar(o: 0.1, h: 0.2, l: -0.1, c: -0.05), Bar(o: -0.05, h: 0.45, l: -0.1, c: 0.42)]
        case "three_methods_up":
            t = [Bar(o: -0.2, h: 0.6, l: -0.25, c: 0.58), Bar(o: 0.55, h: 0.58, l: 0.4, c: 0.42), Bar(o: 0.42, h: 0.45, l: 0.3, c: 0.33), Bar(o: 0.33, h: 0.5, l: 0.3, c: 0.47)]
        case "three_methods_down":
            t = [Bar(o: 0.6, h: 0.65, l: -0.2, c: -0.18), Bar(o: -0.15, h: -0.1, l: -0.3, c: -0.28), Bar(o: -0.25, h: -0.15, l: -0.35, c: -0.2), Bar(o: -0.2, h: -0.1, l: -0.45, c: -0.42)]
        default:
            t = [Bar(o: -0.2, h: 0.2, l: -0.3, c: 0.15), Bar(o: 0.15, h: 0.35, l: 0.0, c: 0.05), Bar(o: 0.05, h: 0.4, l: -0.05, c: 0.32)]
        }
        return t
    }
}
