//
//  Theme.swift
//  TicketLedger
//
//  Colour, gradient and type system. Everything visual in the app comes from here.
//

import SwiftUI

// MARK: - Palette

enum Theme {
    /// Cream page background with a gold undertone.
    static let page = Color(hex: 0xFFF6DE)
    /// Card / token fill.
    static let card = Color(hex: 0xFFFCF0)
    /// Dark anchor — graphite.
    static let anchor = Color(hex: 0x1C1C1A)
    /// Token fill on the dark screen.
    static let darkCard = Color(hex: 0x262624)

    static let gold = Color(hex: 0xE8B21C)
    static let goldLight = Color(hex: 0xFFD84A)
    static let goldDark = Color(hex: 0xB8860B)

    /// Paid, closed, deadline met.
    static let green = Color(hex: 0x3E9B4F)
    /// Expiring window, lost discount.
    static let terracotta = Color(hex: 0xC0451E)
    /// Overdue, enforcement.
    static let maroon = Color(hex: 0x7A1520)

    // MARK: Metal gradient — the key device

    /// 135° four stop fill with a hard break in the middle, so it reads as a
    /// highlight travelling over a metal plate rather than a soft blend.
    static let metal = LinearGradient(
        stops: [
            .init(color: goldDark, location: 0.00),
            .init(color: goldLight, location: 0.50),
            .init(color: gold, location: 0.50),
            .init(color: goldDark, location: 1.00)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Metal gradient shifted along its axis, used for the press highlight.
    static func metalShifted(_ shift: CGFloat) -> LinearGradient {
        let s = min(max(shift, -0.4), 0.4)
        return LinearGradient(
            stops: [
                .init(color: goldDark, location: 0.00),
                .init(color: goldLight, location: max(0.02, min(0.98, 0.50 + s))),
                .init(color: gold, location: max(0.02, min(0.98, 0.50 + s))),
                .init(color: goldDark, location: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Angular version for ring gauges so the highlight travels around the ring.
    static let metalRing = AngularGradient(
        stops: [
            .init(color: goldDark, location: 0.00),
            .init(color: goldLight, location: 0.34),
            .init(color: gold, location: 0.35),
            .init(color: goldDark, location: 0.70),
            .init(color: goldLight, location: 0.88),
            .init(color: goldDark, location: 1.00)
        ],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
}

// MARK: - Typography

enum TypeScale {
    /// Screen title: Display Black, condensed, uppercase, 36pt, tracking +1.
    static let screenTitle = Font.system(size: 36, weight: .black).width(.condensed)
    /// Section title: Text Bold, condensed, uppercase, 14pt, tracking +2.
    static let sectionTitle = Font.system(size: 14, weight: .bold).width(.condensed)
    /// Big numbers: Display Black, condensed, 60pt, monospaced digits.
    static let bigNumber = Font.system(size: 60, weight: .black).width(.condensed).monospacedDigit()
    static func number(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .black).width(.condensed).monospacedDigit()
    }
    /// Notice numbers, plates, article codes: SF Mono Bold 15pt uppercase.
    static let mono = Font.system(size: 15, weight: .bold, design: .monospaced)
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
    static let body = Font.system(size: 16, weight: .regular)
    static let caption = Font.system(size: 13, weight: .semibold)
    static func condensed(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        Font.system(size: size, weight: weight).width(.condensed)
    }
}

extension View {
    func screenTitleStyle(dark: Bool = false) -> some View {
        self.font(TypeScale.screenTitle)
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(dark ? Theme.page : Theme.anchor)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
    }

    func sectionTitleStyle(dark: Bool = false) -> some View {
        self.font(TypeScale.sectionTitle)
            .tracking(2)
            .textCase(.uppercase)
            .foregroundStyle(dark ? Theme.gold : Theme.anchor.opacity(0.55))
    }

    func monoStyle(_ size: CGFloat = 15, dark: Bool = false) -> some View {
        self.font(TypeScale.mono(size))
            .textCase(.uppercase)
            .foregroundStyle(dark ? Theme.page.opacity(0.9) : Theme.anchor)
    }
}

// MARK: - Metrics

enum Metric {
    static let tokenRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 12
    static let buttonHeight: CGFloat = 58
    static let chipHeight: CGFloat = 38
    static let tabBarHeight: CGFloat = 86
    static let holeDiameter: CGFloat = 14
    static let statusBarWidth: CGFloat = 8
    static let screenPadding: CGFloat = 18
    /// Bottom padding for scrolling content so the tab bar never covers it.
    static let contentBottomInset: CGFloat = tabBarHeight + 18
}

// MARK: - Springs

enum Springs {
    /// Token entry: stiffness 360, damping 18.
    static let token = Animation.interpolatingSpring(stiffness: 360, damping: 18)
    /// Tab notch travel: stiffness 300, damping 24.
    static let notch = Animation.interpolatingSpring(stiffness: 300, damping: 24)
    static let sheen = Animation.easeOut(duration: 0.12)
    static let paidSheen = Animation.easeInOut(duration: 0.5)
    static let darkFade = Animation.easeInOut(duration: 0.4)
}

// MARK: - Color helper

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
