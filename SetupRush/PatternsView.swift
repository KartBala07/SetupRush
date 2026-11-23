import SwiftUI

struct PatternsView: View {
    @EnvironmentObject private var app: AppState
    @State private var filter = 0
    @State private var selected: PatternKind?

    private var items: [PatternKind] {
        switch filter {
        case 1: return PatternBook.all.filter { $0.bias > 0 }
        case 2: return PatternBook.all.filter { $0.bias < 0 }
        case 3: return PatternBook.all.filter { $0.bias == 0 }
        default: return PatternBook.all
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filterRow
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(items) { p in
                        Button {
                            Haptic.tap()
                            selected = p
                        } label: {
                            card(p)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .background(Ink.bg.ignoresSafeArea())
        .sheet(item: $selected) { p in
            detail(p)
                .presentationDetents([.medium])
                .presentationBackground(Ink.bg)
        }
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
                Text("PATTERNS.")
                    .font(.system(size: 40, weight: .black).width(.compressed))
                    .foregroundStyle(Ink.ink)
                Spacer()
                Text("\(PatternBook.all.count) DETECTED LIVE")
                    .font(Type_.mono(8, weight: .bold))
                    .foregroundStyle(Ink.dim)
            }
            Text("Candle Vision names the setup the moment it closes. Forming, then confirmed — with a target and a stop.")
                .font(.system(size: 12.5))
                .foregroundStyle(Ink.muted)
                .lineSpacing(2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(["ALL", "BULLISH", "BEARISH", "NEUTRAL"].enumerated()), id: \.offset) { i, t in
                Button {
                    filter = i
                    Haptic.tap()
                } label: {
                    Text(t)
                        .font(Type_.label(10))
                        .tracking(1.2)
                        .foregroundStyle(filter == i ? Ink.bg : Ink.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Chamfer(cut: 5).fill(filter == i ? Ink.ink : Color.clear))
                        .overlay(Chamfer(cut: 5).stroke(filter == i ? .clear : Ink.stroke, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func card(_ p: PatternKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(p.biasLabel)
                    .font(Type_.mono(7, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(p.bias > 0 ? Ink.green : (p.bias < 0 ? Ink.red : Ink.muted))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Ink.dim)
            }
            PatternGlyph(kind: p, tint: p.bias >= 0 ? Ink.ink : Ink.ink)
                .frame(height: 78)
            Text(p.name.uppercased())
                .font(.system(size: 13, weight: .black).width(.condensed))
                .tracking(0.6)
                .foregroundStyle(Ink.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(p.note)
                .font(.system(size: 9.5))
                .foregroundStyle(Ink.muted)
                .lineLimit(2)
        }
        .padding(10)
        .frame(height: 196, alignment: .topLeading)
        .background(Chamfer(cut: 9).fill(Ink.panel))
        .overlay(Chamfer(cut: 9).stroke(Ink.stroke, lineWidth: 1))
    }

    private func detail(_ p: PatternKind) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Tag(text: p.biasLabel, tint: p.bias > 0 ? Ink.green : (p.bias < 0 ? Ink.red : Ink.muted))
                Spacer()
                IconChip(icon: "xmark") { selected = nil }
            }
            Text(p.name.uppercased())
                .font(.system(size: 34, weight: .black).width(.compressed))
                .foregroundStyle(Ink.ink)
            PatternGlyph(kind: p, tint: Ink.ink)
                .frame(height: 120)
                .padding(.horizontal, 30)
                .background(Chamfer(cut: 8).fill(Ink.panel))
            Text(p.note)
                .font(.system(size: 13))
                .foregroundStyle(Ink.muted)
            HStack(spacing: 8) {
                info("ENTRY", "close of the candle")
                info("STOP", "beyond the wick")
                info("TARGET", "2R measured")
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "RIDE THIS SETUP", subtitle: "PRO · 1 MIN") {
                selected = nil
                if let m = MarketStore.shared.markets.first {
                    app.start(mode: .pro, market: m)
                }
            }
        }
        .padding(20)
        .background(Ink.bg)
    }

    private func info(_ t: String, _ d: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t)
                .font(Type_.mono(7.5, weight: .bold))
                .foregroundStyle(Ink.orange)
            Text(d)
                .font(.system(size: 9))
                .foregroundStyle(Ink.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Chamfer(cut: 5).fill(Ink.panel))
    }
}
