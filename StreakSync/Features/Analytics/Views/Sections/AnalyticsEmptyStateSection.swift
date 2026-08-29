//
//  AnalyticsEmptyStateSection.swift
//  StreakSync
//
//  Explains an empty Analytics range and what the user can do to fill it
//

import SwiftUI

/// Rendered in place of the analytics cards when the current time range / game filter has
/// nothing to chart. Without it `AnalyticsDashboardView.contentSection` collapses to
/// nothing and a user with no results sees a blank screen under the time-range picker.
///
/// Follows the house empty-state shape (`GameEmptyState`) and the Friends rule of one
/// dominant explanation with at most one primary action. That action only appears when a
/// single game is selected, because the game filter hides behind a toolbar menu — the
/// time-range picker is already visible directly above this view, and recording a result
/// happens in another app entirely, so neither of those earns a button here.
struct AnalyticsEmptyStateSection: View {
    /// `AnalyticsViewModel.emptyStateMessage` — says what is missing, and for which scope.
    let message: String

    /// True when a single game is selected rather than All Games.
    let isFilteredToOneGame: Bool

    /// Clears the game filter (`AnalyticsViewModel.selectGame(nil)`).
    let onShowAllGames: () -> Void

    // The glyph is sized in points, so it needs @ScaledMetric to grow alongside the text
    // under Dynamic Type instead of shrinking into the paragraph at accessibility sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize = IconSize.xl

    /// Internal rather than private so the copy can be asserted without rendering a view.
    var title: String {
        isFilteredToOneGame ? "No Results for This Game" : "No Results Yet"
    }

    /// The "what you can do next" half of the empty state. `message` states what is
    /// missing; this states how to fix it, which differs by whether a filter is on.
    var guidance: String {
        if isFilteredToOneGame {
            return """
                Try a longer time range above, or show all games to see everything \
                you've tracked.
                """
        }
        return """
            Finish a puzzle like Wordle, tap its share button, then choose StreakSync — \
            every result you send lands here. Already played? Try a longer time range above.
            """
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image.safeSystemName("chart.bar.xaxis", fallback: "chart.bar")
                .font(.system(size: glyphSize, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(guidance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            // Centred to match the rest of the app's empty-state paragraphs, and
            // fixedSize so long copy wraps instead of truncating at large text sizes.
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            // One VoiceOver stop reading heading, then cause, then remedy — rather than
            // three fragments the user has to swipe between to assemble the meaning.
            .accessibilityElement(children: .combine)

            if isFilteredToOneGame {
                Button(action: onShowAllGames) {
                    Text("Show All Games")
                        .font(.subheadline.weight(.semibold))
                        // Inside the label so the button's own hit area clears 44pt
                        // (HIG / WCAG 2.5.8), not just the layout slot around it.
                        .frame(minHeight: Layout.minTouchTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Clears the game filter and charts every game you track")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.huge)
    }
}
