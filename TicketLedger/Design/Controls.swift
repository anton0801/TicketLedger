//
//  Controls.swift
//  TicketLedger
//
//  Buttons, chips, ring gauges, headers and the four list states.
//

import SwiftUI

// MARK: - Primary button (metal)

struct MetalButton: View {
    var title: String
    var icon: String?
    var enabled: Bool = true
    var action: () -> Void

    @State private var sheen: CGFloat = 0

    init(_ title: String, icon: String? = nil, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button {
            guard enabled else { return }
            // The highlight travels across the plate in 0.12s.
            withAnimation(Springs.sheen) { sheen = 0.2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(Springs.sheen) { sheen = 0 }
            }
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .bold)) }
                Text(title)
                    .font(TypeScale.condensed(17, .black))
                    .tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Theme.anchor)
            .frame(maxWidth: .infinity)
            .frame(height: Metric.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                    .fill(Theme.metalShifted(sheen))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                    .strokeBorder(Theme.goldDark, lineWidth: 2)
            )
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Secondary button

struct SecondaryButton: View {
    var title: String
    var icon: String?
    var enabled: Bool = true
    var action: () -> Void

    init(_ title: String, icon: String? = nil, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title)
                    .font(TypeScale.condensed(16, .bold))
                    .tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Theme.goldDark)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                    .strokeBorder(Theme.gold, lineWidth: 2.5)
            )
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Danger button

struct DangerButton: View {
    var title: String
    var icon: String?
    var action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title)
                    .font(TypeScale.condensed(16, .black))
                    .tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                    .fill(Theme.maroon)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chip

struct Chip: View {
    var title: String
    var selected: Bool
    var count: Int?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(TypeScale.condensed(14, selected ? .black : .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(TypeScale.mono(12))
                        .opacity(0.7)
                }
            }
            .foregroundStyle(selected ? Theme.anchor : Theme.goldDark)
            .padding(.horizontal, 14)
            .frame(height: Metric.chipHeight)
            .background(
                Group {
                    if selected {
                        RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                            .fill(Theme.metal)
                    } else {
                        RoundedRectangle(cornerRadius: Metric.buttonRadius, style: .continuous)
                            .strokeBorder(Theme.gold.opacity(0.4), lineWidth: 2)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ring gauge (medallion)

struct RingGauge: View {
    /// Remaining fraction, 0…1.
    var progress: Double
    var value: String
    var label: String
    var caption: String?
    /// nil means the metal gradient; a colour overrides it (expired / enforcement).
    var tint: Color?
    var diameter: CGFloat = 104
    var dimmed: Bool = false
    var dark: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .strokeBorder(
                        (dark ? Theme.page : Theme.anchor).opacity(0.12),
                        lineWidth: 10
                    )
                if !dimmed {
                    Circle()
                        .trim(from: 0, to: max(0.005, min(1, progress)))
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundStyle(ringShading)
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: -2) {
                    Text(value)
                        .font(TypeScale.number(diameter * 0.34))
                        .foregroundStyle(dark ? Theme.page : Theme.anchor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if let caption {
                        Text(caption)
                            .font(TypeScale.condensed(10, .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.5))
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(width: diameter, height: diameter)

            Text(label)
                .font(TypeScale.condensed(11, .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .foregroundStyle(dark ? Theme.gold : Theme.anchor.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ringShading: AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint) }
        return AnyShapeStyle(Theme.metalRing)
    }
}

// MARK: - Headers

struct ScreenHeader: View {
    var title: String
    var subtitle: String?
    var dark: Bool = false
    var trailing: AnyView?

    init(_ title: String, subtitle: String? = nil, dark: Bool = false, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.dark = dark
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).screenTitleStyle(dark: dark)
                if let subtitle {
                    Text(subtitle)
                        .font(TypeScale.caption)
                        .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.55))
                }
            }
            Spacer(minLength: 8)
            if let trailing { trailing }
        }
    }
}

struct SectionHeader: View {
    var title: String
    var dark: Bool = false
    var trailing: String?

    init(_ title: String, dark: Bool = false, trailing: String? = nil) {
        self.title = title
        self.dark = dark
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title).sectionTitleStyle(dark: dark)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(TypeScale.mono(12))
                    .foregroundStyle((dark ? Theme.gold : Theme.anchor).opacity(0.5))
            }
        }
    }
}

/// Gold 2px rule used between rows and tables.
struct GoldRule: View {
    var opacity: Double = 0.35
    var body: some View {
        Rectangle()
            .fill(Theme.gold.opacity(opacity))
            .frame(height: 2)
    }
}

// MARK: - States

struct LoadingState: View {
    var message: String = "Opening your ledger"
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Theme.goldDark)
                .scaleEffect(1.2)
            Text(message)
                .font(TypeScale.condensed(14, .bold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyState: View {
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.goldDark.opacity(0.8))
            Text(title)
                .font(TypeScale.condensed(22, .black))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor)
                .multilineTextAlignment(.center)
            Text(message)
                .font(TypeScale.body)
                .foregroundStyle(Theme.anchor.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                MetalButton(actionTitle, action: action)
                    .padding(.top, 4)
                    .padding(.horizontal, 24)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                    .fill(Theme.card)
                Guilloche()
                    .clipShape(RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.5), lineWidth: 2)
        )
    }
}

struct ErrorState: View {
    var title: String
    var message: String
    var retryTitle: String = "Try Again"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.terracotta)
            Text(title)
                .font(TypeScale.condensed(20, .black))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.anchor)
                .multilineTextAlignment(.center)
            Text(message)
                .font(TypeScale.body)
                .foregroundStyle(Theme.anchor.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                SecondaryButton(retryTitle, action: retry).padding(.top, 4)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metric.tokenRadius, style: .continuous)
                .strokeBorder(Theme.terracotta.opacity(0.6), lineWidth: 2)
        )
    }
}

// MARK: - Standing notice

/// The permanent line shown wherever deadlines are displayed.
struct DeadlineDisclaimer: View {
    var dark: Bool = false
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .bold))
            Text("This app tracks dates you enter. It is not legal advice and it does not connect to any official register. Check the fine itself and the deadlines printed on it.")
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.5))
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill((dark ? Theme.page : Theme.anchor).opacity(0.05))
        )
    }
}

// MARK: - Key/value row

struct DetailRow: View {
    var label: String
    var value: String
    var mono: Bool = false
    var valueColor: Color?
    var dark: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(TypeScale.condensed(13, .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle((dark ? Theme.page : Theme.anchor).opacity(0.5))
                .frame(width: 128, alignment: .leading)
            Text(value)
                .font(mono ? TypeScale.mono(14) : TypeScale.body)
                .foregroundStyle(valueColor ?? (dark ? Theme.page : Theme.anchor))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 7)
    }
}
