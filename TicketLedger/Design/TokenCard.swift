//
//  TokenCard.swift
//  TicketLedger
//
//  The signature shape: a jeton. Rounded rectangle, double embossed border
//  (3px metal outside, 1px gold inset 5pt), two drilled holes on the left and
//  right edges, a status stripe inside the left border. No shadows — the
//  volume comes from the double border and the metal.
//

import SwiftUI

struct TokenCard<Content: View>: View {
    var status: Color?
    var dark: Bool = false
    var showsGuilloche: Bool = true
    var showsHoles: Bool = true
    /// Highlight travel for the metal border, 0 at rest.
    var sheen: CGFloat = 0
    @ViewBuilder var content: () -> Content

    private var fill: Color { dark ? Theme.darkCard : Theme.card }
    private var holeFill: Color { dark ? Theme.anchor : Theme.page }

    var body: some View {
        content()
            .padding(.leading, status == nil ? 16 : 22)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                // Fill first, then the guilloche on top of it — the motif has to
                // sit inside the token, not behind an opaque plate.
                ZStack {
                    RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                        .fill(fill)
                    if showsGuilloche {
                        Guilloche(opacity: dark ? 0.24 : 0.18)
                            .clipShape(RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous))
                    }
                }
            )
            .overlay(alignment: .leading) {
                if let status {
                    RoundedRectangle(cornerRadius: Metric.statusBarWidth / 2, style: .continuous)
                        .fill(status)
                        .frame(width: Metric.statusBarWidth)
                        .padding(.vertical, 10)
                        .padding(.leading, 6)
                }
            }
            // Inner hairline, inset 5pt.
            .overlay(
                RoundedRectangle(cornerRadius: Metric.tokenRadius - 5, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(dark ? 0.75 : 0.9), lineWidth: 1)
                    .padding(5)
            )
            // Outer metal border, 3px.
            .overlay(
                RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                    .strokeBorder(Theme.metalShifted(sheen), lineWidth: 3)
            )
            .overlay(alignment: .leading) { hole(visible: showsHoles) }
            .overlay(alignment: .trailing) { hole(visible: showsHoles) }
    }

    @ViewBuilder
    private func hole(visible: Bool) -> some View {
        if visible {
            Circle()
                .fill(holeFill)
                .overlay(Circle().strokeBorder(Theme.goldDark, lineWidth: 2))
                .frame(width: Metric.holeDiameter, height: Metric.holeDiameter)
                .padding(.horizontal, 6)
        }
    }
}

// MARK: - Entry animation

/// Tokens arrive rotated 3° with a small bounce, on a 360/18 spring.
struct TokenAppear: ViewModifier {
    var index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(shown ? 0 : 3))
            .scaleEffect(shown ? 1 : 0.94)
            .opacity(shown ? 1 : 0)
            .onAppear {
                let delay = min(Double(index) * 0.045, 0.4)
                withAnimation(Springs.token.delay(delay)) { shown = true }
            }
    }
}

extension View {
    func tokenAppear(_ index: Int) -> some View {
        modifier(TokenAppear(index: index))
    }
}

// MARK: - Paid stamp

/// Green PAID stamp, set at 6°, that replaces a token when the fine is settled.
struct PaidStamp: View {
    var text: String = "PAID"

    var body: some View {
        Text(text)
            .font(TypeScale.condensed(34, .black))
            .tracking(4)
            .foregroundStyle(Theme.green)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.green, lineWidth: 4)
            )
            .rotationEffect(.degrees(-6))
    }
}

#Preview {
    ZStack {
        Theme.page.ignoresSafeArea()
        VStack(spacing: 18) {
            TokenCard(status: Theme.terracotta) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Parking, zone 3").sectionTitleStyle()
                    Text("AB 123 CD").monoStyle()
                    Text("40").font(TypeScale.bigNumber)
                }
            }
            PaidStamp()
        }
        .padding()
    }
}
