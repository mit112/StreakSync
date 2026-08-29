//
//  StreakOverviewAccessoryViews.swift
//  StreakSyncWidget
//
//  Lock Screen families: circular, rectangular, inline
//

import SwiftUI
import WidgetKit

/// Accessory families render in `.accented` or `.vibrant` mode, never
/// `.fullColor`, so none of these views carries a per-game tint — they lean on
/// `.widgetAccentable()` and the system's own treatment instead.

/// accessoryCircular: the longest current streak, nothing else.
struct StreakCircularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                Text(snapshot.longestCurrentStreak, format: .number)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(WidgetSpacing.tight)
        }
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Longest current streak")
        .accessibilityValue(snapshot.longestStreakSummary)
        .widgetURL(WidgetDeepLink.openApp)
    }
}

/// accessoryRectangular: streak on top, what is at risk underneath.
struct StreakRectangularView: View {
    let snapshot: WidgetSnapshot

    /// The at-risk line is the reason to glance at this one, so the tap goes to
    /// the game it is talking about when there is one.
    private var destination: URL {
        guard let game = snapshot.mostUrgentGame else {
            return WidgetDeepLink.openApp
        }
        return WidgetDeepLink.game(id: game.gameId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetSpacing.hair) {
            Label {
                Text(snapshot.longestStreakSummary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: "flame.fill")
            }
            .font(.headline)
            .widgetAccentable()

            Text(snapshot.atRiskSummary)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshot.longestStreakSummary). \(snapshot.atRiskSummary).")
        .widgetURL(destination)
    }
}

/// accessoryInline: one line, in whatever space the system gives it.
struct StreakInlineView: View {
    let snapshot: WidgetSnapshot

    private var text: String {
        guard snapshot.atRiskCount > 0 else {
            return snapshot.longestStreakSummary
        }
        return "\(snapshot.longestStreakSummary) · \(snapshot.atRiskSummary)"
    }

    var body: some View {
        Label(text, systemImage: "flame.fill")
            .accessibilityLabel(text)
            .widgetURL(WidgetDeepLink.openApp)
    }
}
