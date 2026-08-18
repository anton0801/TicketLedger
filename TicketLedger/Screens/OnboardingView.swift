//
//  OnboardingView.swift
//  TicketLedger
//
//  Four screens. The first three explain why dates cost more than fines; the
//  fourth hands over to setup, which cannot be skipped.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(Store.self) private var store
    @State private var page = 0

    private let pageCount = 4

    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    OnboardingPage(
                        eyebrow: "01 · Why this exists",
                        title: "The Fine Is Not the Cost",
                        text: "A parking fine is annoying. Paying it eleven days late, at double, after the discount ran out, is what actually costs money.\n\nThis app does not add up your debt. It counts dates, and puts them in the order of what waiting costs you.",
                        illustration: AnyView(PriceIllustration())
                    ).tag(0)

                    OnboardingPage(
                        eyebrow: "02 · How a fine works",
                        title: "Three Clocks on Every Fine",
                        text: "Every notice runs three separate countdowns, and they end on different days.\n\nThe discount holds for a while. The right to appeal closes sooner. After a longer date, the debt goes to enforcement and costs are added on top.",
                        illustration: AnyView(ClocksIllustration())
                    ).tag(1)

                    OnboardingPage(
                        eyebrow: "03 · The part people skip",
                        title: "Who Was Driving Matters",
                        text: "If someone else had the keys, \"pay or appeal\" is a different conversation — and a different set of documents.\n\nWrite the driver down while you still remember. In three weeks you will not, and the appeal window will be shut.",
                        illustration: AnyView(DriverIllustration())
                    ).tag(2)

                    OnboardingPage(
                        eyebrow: "04 · One thing to set up",
                        title: "Add Your Vehicle",
                        text: "Next you will enter one car and the three deadline windows that apply where you are.\n\nThose windows differ by country and by type of fine, so they are yours to set. The app suggests a starting point and never pretends to know your local rule.",
                        illustration: AnyView(PlateIllustration())
                    ).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)

                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index == page ? AnyShapeStyle(Theme.metal) : AnyShapeStyle(Theme.gold.opacity(0.3)))
                                .frame(width: index == page ? 28 : 10, height: 5)
                                .animation(Springs.notch, value: page)
                        }
                    }

                    if page < pageCount - 1 {
                        MetalButton("Next") {
                            withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                        }
                        Button("Skip the explanation") {
                            finish()
                        }
                        .font(TypeScale.caption)
                        .foregroundStyle(Theme.anchor.opacity(0.45))
                    } else {
                        MetalButton("Continue To Setup") { finish() }
                        Text("Nothing leaves this device. There is no account and no register.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.anchor.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Metric.screenPadding)
                .padding(.bottom, 26)
                .padding(.top, 10)
            }
        }
    }

    private func finish() {
        var settings = store.data.settings
        settings.onboardingDone = true
        store.settings = settings
    }
}

// MARK: - Page shell

private struct OnboardingPage: View {
    var eyebrow: String
    var title: String
    var text: String
    var illustration: AnyView

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(eyebrow)
                    .font(TypeScale.condensed(12, .bold))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.goldDark)

                Text(title).screenTitleStyle()

                illustration
                    .frame(height: 190)

                Text(text)
                    .font(TypeScale.body)
                    .foregroundStyle(Theme.anchor.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metric.screenPadding)
            .padding(.top, 44)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Illustrations, built from the same parts as the app

private struct PriceIllustration: View {
    var body: some View {
        TokenCard(status: Theme.terracotta) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Same notice, two dates")
                    .sectionTitleStyle()
                HStack(alignment: .lastTextBaseline, spacing: 14) {
                    VStack(alignment: .leading, spacing: -4) {
                        Text("40").font(TypeScale.number(52))
                            .foregroundStyle(Theme.green)
                        Text("Until 18 March")
                            .font(TypeScale.condensed(11, .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor.opacity(0.5))
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.goldDark)
                        .padding(.bottom, 16)
                    VStack(alignment: .leading, spacing: -4) {
                        Text("80").font(TypeScale.number(52))
                            .foregroundStyle(Theme.terracotta)
                        Text("On 19 March")
                            .font(TypeScale.condensed(11, .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.anchor.opacity(0.5))
                    }
                }
                Text("One day of delay: 40.")
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.terracotta)
            }
        }
    }
}

private struct ClocksIllustration: View {
    var body: some View {
        TokenCard(status: Theme.gold) {
            HStack(spacing: 10) {
                RingGauge(progress: 0.3, value: "6", label: "Discount", caption: "days", tint: nil, diameter: 74)
                RingGauge(progress: 0.2, value: "2", label: "Appeal", caption: "days", tint: Theme.terracotta, diameter: 74)
                RingGauge(progress: 0.72, value: "51", label: "Enforce", caption: "days", tint: Theme.maroon, diameter: 74)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct DriverIllustration: View {
    var body: some View {
        TokenCard(status: Theme.goldDark) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Driver at the time")
                    .sectionTitleStyle()
                HStack(spacing: 10) {
                    ForEach(["Me", "Marta", "Employee"], id: \.self) { name in
                        Text(name)
                            .font(TypeScale.condensed(14, name == "Marta" ? .black : .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(name == "Marta" ? Theme.anchor : Theme.goldDark)
                            .padding(.horizontal, 12)
                            .frame(height: Metric.chipHeight)
                            .background(
                                Group {
                                    if name == "Marta" {
                                        RoundedRectangle(cornerRadius: 12).fill(Theme.metal)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Theme.gold.opacity(0.4), lineWidth: 2)
                                    }
                                }
                            )
                    }
                }
                GoldRule()
                Text("Recorded on the day, not in three weeks.")
                    .font(TypeScale.caption)
                    .foregroundStyle(Theme.anchor.opacity(0.6))
            }
        }
    }
}

private struct PlateIllustration: View {
    var body: some View {
        TokenCard(status: Theme.green) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your first vehicle")
                    .sectionTitleStyle()
                Text("AB 123 CD")
                    .font(TypeScale.mono(28))
                    .foregroundStyle(Theme.anchor)
                GoldRule()
                HStack(spacing: 18) {
                    ForEach(["Insurance", "Inspection", "Road tax"], id: \.self) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item)
                                .font(TypeScale.condensed(10, .bold))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundStyle(Theme.anchor.opacity(0.45))
                            Text("—")
                                .font(TypeScale.mono(13))
                                .foregroundStyle(Theme.goldDark)
                        }
                    }
                }
            }
        }
    }
}
