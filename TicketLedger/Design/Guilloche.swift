//
//  Guilloche.swift
//  TicketLedger
//
//  The motif: a mesh of thin intersecting arcs, like the security pattern on a
//  printed form. Lives inside tokens, empty states and vehicle headers only —
//  it never bleeds past the edge of a block.
//

import SwiftUI

struct Guilloche: View {
    /// 18% is the standard weight; the dark screen raises it.
    var opacity: Double = 0.18
    var spacing: CGFloat = 30
    var lineWidth: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let stroke = GraphicsContext.Shading.color(Theme.gold.opacity(opacity))
            let h = max(size.height, 1)
            let w = max(size.width, 1)
            // A large radius keeps the arcs shallow, so the mesh stays even
            // instead of bunching into a dark band across the middle.
            let radius = max(h, 120) * 2.4

            // Family A — shallow arcs swung from below the block.
            var x = -radius * 0.5
            while x < w + radius * 0.5 {
                var path = Path()
                path.addArc(
                    center: CGPoint(x: x, y: h + radius - h * 0.45),
                    radius: radius,
                    startAngle: .degrees(250),
                    endAngle: .degrees(290),
                    clockwise: false
                )
                context.stroke(path, with: stroke, lineWidth: lineWidth)
                x += spacing
            }

            // Family B — the same, mirrored from above, so the two cross.
            x = -radius * 0.5
            while x < w + radius * 0.5 {
                var path = Path()
                path.addArc(
                    center: CGPoint(x: x + spacing / 2, y: -radius + h * 0.45),
                    radius: radius,
                    startAngle: .degrees(70),
                    endAngle: .degrees(110),
                    clockwise: false
                )
                context.stroke(path, with: stroke, lineWidth: lineWidth)
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Theme.page.ignoresSafeArea()
        RoundedRectangle(cornerRadius: 14)
            .fill(Theme.card)
            .overlay(Guilloche().clipShape(RoundedRectangle(cornerRadius: 14)))
            .frame(height: 180)
            .padding()
    }
}
