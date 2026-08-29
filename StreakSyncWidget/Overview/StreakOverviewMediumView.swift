//
//  StreakOverviewMediumView.swift
//  StreakSyncWidget
//
//  systemMedium: a summary line plus per-game chips
//

import SwiftUI
import WidgetKit

/// A one-line summary over a two-column grid of chips. Each chip is its own
/// `Link`; the header falls through to `widgetURL`.
struct StreakOverviewMediumView: View {
    let snapshot: WidgetSnapshot

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var isFullColor: Bool {
        renderingMode == .fullColor
    }

    /// Six chips fit at default text sizes; at accessibility sizes each chip is
    /// taller, so drop to four rather than clipping the bottom row.
    private var chipLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 4 : 6
    }

    private let columns = [
        GridItem(.flexible(), spacing: WidgetSpacing.row),
        GridItem(.flexible(), spacing: WidgetSpacing.row)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetSpacing.row) {
            header
            LazyVGrid(columns: columns, alignment: .leading, spacing: WidgetSpacing.tight) {
                ForEach(snapshot.topGames(limit: chipLimit)) { game in
                    GameChipView(entry: game)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeepLink.openApp)
    }

    private var header: some View {
        HStack(spacing: WidgetSpacing.block) {
            summary(
                symbolName: "flame.fill",
                text: snapshot.longestStreakSummary,
                tint: WidgetTint.streak
            )
            if snapshot.atRiskCount > 0 {
                summary(
                    symbolName: "exclamationmark.triangle.fill",
                    text: snapshot.atRiskSummary,
                    tint: WidgetTint.atRisk
                )
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerLabel)
    }

    private var headerLabel: String {
        "\(snapshot.longestStreakSummary). \(snapshot.atRiskSummary). \(snapshot.completedTodaySummary)."
    }

    private func summary(symbolName: String, text: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } icon: {
            Image(systemName: symbolName)
                .font(.caption)
                .foregroundStyle(isFullColor ? tint : .primary)
        }
    }
}
