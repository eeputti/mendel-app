#if !WIDGET_EXTENSION
//
// PaywallView.swift
// Purchase unlock surface kept intact.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseManager.self) private var store
    @State private var appeared = false

    private let features: [(icon: String, title: String, detail: String)] = [
        ("bubble.left", "coach — unlimited", "ask anything, anytime"),
        ("chart.bar", "weekly planning", "structured 7-day build"),
        ("arrow.up.right", "load trends", "track progress over time"),
        ("sparkles", "smarter engine", "recommendations that learn"),
    ]

    var body: some View {
        ZStack {
            MendelColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MendelColors.inkSoft)
                            .frame(width: 30, height: 30)
                            .background(MendelColors.inkFaint, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, MendelSpacing.xl)
                .padding(.top, 20)

                Spacer()

                VStack(spacing: 8) {
                    Text(AppStrings.Paywall.brandLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MendelColors.inkSoft)
                        .tracking(2.0)
                        .textCase(.uppercase)
                    Text("unlock\neverything")
                        .font(.system(size: 52, weight: .heavy))
                        .foregroundStyle(MendelColors.ink)
                        .tracking(-2)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.easeOut(duration: 0.45).delay(0.05), value: appeared)
                    Text("one payment. no subscription. yours forever.")
                        .font(MendelType.caption())
                        .foregroundStyle(MendelColors.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.12), value: appeared)
                }
                .padding(.horizontal, MendelSpacing.xl)

                Spacer().frame(height: 48)

                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(MendelColors.inkFaint.opacity(0.6))
                                    .frame(width: 36, height: 36)
                                Image(systemName: feature.icon)
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundStyle(MendelColors.ink)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(MendelType.bodyMedium())
                                    .foregroundStyle(MendelColors.ink)
                                Text(feature.detail)
                                    .font(MendelType.caption())
                                    .foregroundStyle(MendelColors.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MendelColors.stone)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        if index < features.count - 1 {
                            Rectangle()
                                .fill(MendelColors.inkFaint)
                                .frame(height: 0.5)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(MendelColors.white, in: RoundedRectangle(cornerRadius: MendelRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: MendelRadius.md)
                        .stroke(MendelColors.inkFaint, lineWidth: 0.5)
                )
                .padding(.horizontal, MendelSpacing.xl)

                Spacer()

                VStack(spacing: 12) {
                    if let error = store.error {
                        Text(error)
                            .font(MendelType.caption())
                            .foregroundStyle(Color.red.opacity(0.7))
                    }

                    Button {
                        Task { await store.purchase() }
                    } label: {
                        ZStack {
                            if store.isLoading {
                                ProgressView().tint(MendelColors.bg)
                            } else {
                                Text("unlock for \(store.formattedPrice)")
                                    .font(MendelType.bodyMedium())
                                    .foregroundStyle(MendelColors.bg)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(MendelColors.ink, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isLoading)

                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text("restore purchase")
                            .font(MendelType.caption())
                            .foregroundStyle(MendelColors.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isLoading)
                }
                .padding(.horizontal, MendelSpacing.xl)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation {
                    appeared = true
                }
            }
        }
        .onChange(of: store.isUnlocked) {
            if store.isUnlocked {
                dismiss()
            }
        }
    }
}
#endif
