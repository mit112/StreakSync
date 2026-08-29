//
//  SingleGameWidget.swift
//  StreakSyncWidget
//
//  Configurable widget pinning one game's streak
//

import SwiftUI
import WidgetKit

struct SingleGameWidget: Widget {
    static let kind = "StreakSyncSingleGame"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectGameIntent.self,
            provider: SingleGameProvider()
        ) { entry in
            SingleGameEntryView(entry: entry)
        }
        .configurationDisplayName("Game Streak")
        .description("Pin one game. Touch and hold the widget to choose which.")
        .supportedFamilies([.systemSmall])
    }
}
