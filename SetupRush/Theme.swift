import SwiftUI

// MARK: - Palette (sampled from setuprush.com)

enum Ink {
    static let bg = Color(hex: 0x0C0C0D)
    static let bgLift = Color(hex: 0x111113)
    static let panel = Color(hex: 0x151517)
    static let panelLift = Color(hex: 0x1B1B1E)
    static let stroke = Color(hex: 0x2C2C31)
    static let strokeSoft = Color(hex: 0x1F1F23)
    static let ink = Color(hex: 0xF4F3EF)
    static let muted = Color(hex: 0x8A8A91)
    static let dim = Color(hex: 0x5B5B62)
    static let orange = Color(hex: 0xFF5A1F)
    static let amber = Color(hex: 0xFFB020)
    static let green = Color(hex: 0x35D07A)
    static let red = Color(hex: 0xFF4B3E)
    static let blue = Color(hex: 0x6FA8FF)
    static let paper = Color(hex: 0xEDEBE3)
    static let paperInk = Color(hex: 0x16161A)
    static let paperGrid = Color(hex: 0xD6D2C4)
    static let paperMuted = Color(hex: 0x8C8778)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Type

enum Type_ {
    /// Poster display face: heavy, condensed, all caps.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }
    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .bold).width(.condensed)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Shapes

/// Panel with cut (chamfered) corners — the HUD language of the site.
struct Chamfer: Shape {
    var cut: CGFloat = 10
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = min(cut, min(r.width, r.height) / 2)
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.closeSubpath()
        return p
    }
}

struct BracketCorners: View {
    var color: Color = Ink.orange
    var length: CGFloat = 14
    var thickness: CGFloat = 2
    var inset: CGFloat = -6

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                let i = inset, l = length
                p.move(to: CGPoint(x: i, y: i + l)); p.addLine(to: CGPoint(x: i, y: i)); p.addLine(to: CGPoint(x: i + l, y: i))
                p.move(to: CGPoint(x: w - i - l, y: i)); p.addLine(to: CGPoint(x: w - i, y: i)); p.addLine(to: CGPoint(x: w - i, y: i + l))
                p.move(to: CGPoint(x: i, y: h - i - l)); p.addLine(to: CGPoint(x: i, y: h - i)); p.addLine(to: CGPoint(x: i + l, y: h - i))
                p.move(to: CGPoint(x: w - i - l, y: h - i)); p.addLine(to: CGPoint(x: w - i, y: h - i)); p.addLine(to: CGPoint(x: w - i, y: h - i - l))
            }
            .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .square))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Backgrounds

struct DotGrid: View {
    var color: Color = Color.white.opacity(0.055)
    var spacing: CGFloat = 22
    var dot: CGFloat = 1

    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// Film-grain-ish scanline texture used behind the hero chart.
struct GridLines: View {
    var color: Color = Color.white.opacity(0.05)
    var step: CGFloat = 40

    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = 0
            while x < size.width {
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                }, with: .color(color), lineWidth: 0.5)
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                }, with: .color(color), lineWidth: 0.5)
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Components

struct SectionLabel: View {
    var text: String
    var index: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Ink.orange).frame(width: 6, height: 6)
            Text(text.uppercased())
                .font(Type_.label(11))
                .tracking(2.4)
                .foregroundStyle(Ink.muted)
            Spacer()
            if let index {
                Text(index)
                    .font(Type_.mono(10, weight: .semibold))
                    .foregroundStyle(Ink.dim)
            }
        }
    }
}

struct Tag: View {
    var text: String
    var tint: Color = Ink.muted
    var filled: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(Type_.label(10))
            .tracking(1.2)
            .foregroundStyle(filled ? Ink.bg : tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(filled ? tint : Color.clear)
            .overlay(Chamfer(cut: 4).stroke(filled ? .clear : Ink.stroke, lineWidth: 1))
    }
}

struct PrimaryButton: View {
    var title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var color: Color = Ink.orange
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title.uppercased())
                    .font(.system(size: 19, weight: .black).width(.compressed))
                    .tracking(1.6)
                if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .black))
                }
                Spacer(minLength: 0)
                if let subtitle {
                    Text(subtitle.uppercased())
                        .font(Type_.label(10))
                        .tracking(1.4)
                        .opacity(0.62)
                }
            }
            .foregroundStyle(Ink.bg)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(Chamfer(cut: 12).fill(color))
            .overlay(BracketCorners(color: color, length: 12, thickness: 2, inset: -5))
        }
        .buttonStyle(PressStyle())
    }
}

struct GhostButton: View {
    var title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(title.uppercased())
                    .font(Type_.label(12))
                    .tracking(1.4)
            }
            .foregroundStyle(Ink.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Chamfer(cut: 9).stroke(Ink.stroke, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct HudStat: View {
    var label: String
    var value: String
    var tint: Color = Ink.ink
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(Type_.mono(8.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.muted)
            Text(value)
                .font(Type_.mono(15, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Helpers

extension Double {
    var money: String {
        let sign = self < 0 ? "−" : "+"
        let v = abs(self)
        if v >= 1000 {
            return "\(sign)$" + String(format: "%.0f", v)
        }
        return "\(sign)$" + String(format: "%.0f", v)
    }
    var signedPct: String {
        (self < 0 ? "−" : "+") + String(format: "%.1f%%", abs(self))
    }
    var priceString: String {
        if self >= 1000 { return String(format: "%.0f", self) }
        if self >= 100 { return String(format: "%.2f", self) }
        if self >= 1 { return String(format: "%.3f", self) }
        if self >= 0.01 { return String(format: "%.4f", self) }
        return String(format: "%.6f", self)
    }
}

enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warn() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
