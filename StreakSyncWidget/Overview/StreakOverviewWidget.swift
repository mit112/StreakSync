//
//  StreakOverviewWidget.swift
//  StreakSyncWidget
//
//  Streak overview across every tracked game
//

import SwiftUI
import WidgetKit

struct StreakOverviewWidget: Widget {
    static let kind = "StreakSyncStreakOverview"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: StreakOverviewProvider()) { entry in
            StreakOverviewEntryView(entry: entry)
        }
        .configurationDisplayName("Streaks")
        .description("Your longest streak and the games about to break one.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct StreakOverviewEntryView: View {
    let entry: StreakOverviewEntry

    @Environment(\.widgetFamily) private var family

    /// Lock Screen and watch complications draw on top of the wallpaper, so they
    /// take a clear container instead of a filled card.
    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return true
        default:
            return false
        }
    }

    var body: some View {
        if isAccessory {
            content.containerBackground(.clear, for: .widget)
        } else {
            content.containerBackground(.background, for: .widget)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = entry.snapshot {
            if snapshot.games.isEmpty {
                WidgetMessageView.noStreaks
            } else {
                populated(snapshot)
            }
        } else {
            WidgetMessageView.noData
        }
    }

    @ViewBuilder
    private func populated(_ snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .systemMedium:
            StreakOverviewMediumView(snapshot: snapshot)
        case .accessoryCircular:
            StreakCircularView(snapshot: snapshot)
        case .accessoryRectangular:
            StreakRectangularView(snapshot: snapshot)
        case .accessoryInline:
            StreakInlineView(snapshot: snapshot)
        default:
            StreakOverviewSmallView(snapshot: snapshot)
        }
    }
}
