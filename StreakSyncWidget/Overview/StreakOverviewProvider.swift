//
//  StreakOverviewProvider.swift
//  StreakSyncWidget
//
//  Timeline for the streak-overview widget: now, next midnight, then reload
//

import Foundation
import WidgetKit

struct StreakOverviewEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has published a snapshot at least once.
    let snapshot: WidgetSnapshot?
}

/// Reads only `WidgetSnapshot.loadFromAppGroup()`. It never touches `GameCatalog`,
/// `AppState`, or anything under `Core/Services` — those are main-actor bound,
/// read `UserDefaults.standard`, or pull in Firebase, none of which a widget
/// process can do.
struct StreakOverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakOverviewEntry {
        StreakOverviewEntry(date: Date(), snapshot: WidgetSampleData.snapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakOverviewEntry) -> Void) {
        let now = Date()
        if context.isPreview {
            completion(StreakOverviewEntry(date: now, snapshot: WidgetSampleData.snapshot))
            return
        }
        let snapshot = WidgetSnapshot.loadFromAppGroup()?.rolledForward(to: now)
        completion(StreakOverviewEntry(date: now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakOverviewEntry>) -> Void) {
        let published = WidgetSnapshot.loadFromAppGroup()
        if published == nil {
            WidgetLog.timeline.notice("No published snapshot; rendering the open-app placeholder")
        }
        let plan = WidgetTimelinePlan.make(snapshot: published)
        let entries = [
            StreakOverviewEntry(date: plan.now, snapshot: plan.current),
            StreakOverviewEntry(date: plan.nextMidnight, snapshot: plan.afterMidnight)
        ]
        completion(Timeline(entries: entries, policy: .after(plan.reloadAt)))
    }
}
