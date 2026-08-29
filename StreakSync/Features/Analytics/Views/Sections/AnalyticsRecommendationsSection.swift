//
//  AnalyticsRecommendationsSection.swift
//  StreakSync
//
//  One primary recommendation plus up to two secondary ones, each actually tappable
//

import SwiftUI

struct AnalyticsRecommendationsSection: View {
    let recommendations: [AnalyticsRecommendation]
    let onSelect: (AnalyticsRecommendation) -> Void

    init(
        recommendations: [AnalyticsRecommendation],
        onSelect: @escaping (AnalyticsRecommendation) -> Void
    ) {
        self.recommendations = recommendations
        self.onSelect = onSelect
    }

    var body: some View {
        // Nothing at all when there is nothing to recommend: an empty card with a heading
        // was the old passive-lightning-row problem in a new shape (DESIGN_AUDIT §4.8).
        if recommendations.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("What to do next")
                    .font(.headline)
                    .fontWeight(.semibold)

                ForEach(Array(recommendations.prefix(3).enumerated()), id: \.element.id) { index, recommendation in
                    if index == 0 {
                        Button { onSelect(recommendation) } label: { label(for: recommendation) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(StreakSyncBrand.primary)
                            .accessibilityHint("Opens achievement progress.")
                    } else {
                        Button { onSelect(recommendation) } label: { label(for: recommendation) }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .tint(StreakSyncBrand.primary)
                            .accessibilityHint("Opens achievement progress.")
                    }
                }
            }
            .padding()
            .cardStyle()
        }
    }

    private func label(for recommendation: AnalyticsRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(recommendation.title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(recommendation.detail)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
