//
//  StreakSummaryMetricView.swift
//  StreakSync
//
//  Flexible metric cell used by the Home streak summary.
//

import SwiftUI

struct StreakSummaryMetricView: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label {
                Text(value)
                    .font(isPrimary ? .title.bold() : .title2.bold())
                    .monospacedDigit()
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

#Preview {
    StreakSummaryMetricView(
        icon: "flame.fill",
        value: "14",
        label: "day streak",
        tint: StreakSyncBrand.streak,
        isPrimary: true
    )
    .padding()
}
