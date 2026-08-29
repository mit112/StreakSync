//
//  SingleGameProvider.swift
//  StreakSyncWidget
//
//  Timeline for the configurable single-game widget
//

import Foundation
import WidgetKit

struct SingleGameEntry: TimelineEntry {
    let date: Date
    /// Catalog identity for the configured game. Survives the case where the
    /// user has picked a game they have never played, so the widget still shows
    /// the right name, icon, and color instead of going blank.
    let game: Game?
    /// Live streak state. Nil when no snapshot exists, or when the snapshot
    /// carries no row for this game.
    let state: WidgetGameEntry?
    /// False only when the app has never published a snapshot — the difference
    /// between "open the app once" and "you haven't played this one yet".
    let hasSnapshot: Bool
}

struct SingleGameProvider: AppIntentTimelineProvider {
    typealias Entry = SingleGameEntry
    typealias Intent = SelectGameIntent

    func placeholder(in context: Context) -> SingleGameEntry {
        SingleGameEntry(
            date: Date(),
            game: Game.allAvailableGames.first,
            state: WidgetSampleData.firstGame,
            hasSnapshot: true
        )
    }

    func snapshot(for configuration: SelectGameIntent, in context: Context) async -> SingleGameEntry {
        let now = Date()
        let published = context.isPreview ? WidgetSampleData.snapshot : WidgetSnapshot.loadFromAppGroup()
        return makeEntry(
            for: configuration,
            at: now,
            snapshot: published?.rolledForward(to: now),
            hasSnapshot: published != nil
        )
    }

    func timeline(for configuration: SelectGameIntent, in context: Context) async -> Timeline<SingleGameEntry> {
        let published = WidgetSnapshot.loadFromAppGroup()
        if published == nil {
            WidgetLog.timeline.notice("Single-game timeline built with no published snapshot")
        }
        let plan = WidgetTimelinePlan.make(snapshot: published)
        let entries = [
            makeEntry(for: configuration, at: plan.now, snapshot: plan.current, hasSnapshot: published != nil),
            makeEntry(
                for: configuration,
                at: plan.nextMidnight,
                snapshot: plan.afterMidnight,
                hasSnapshot: published != nil
            )
        ]
        return Timeline(entries: entries, policy: .after(plan.reloadAt))
    }

    private func makeEntry(
        for configuration: SelectGameIntent,
        at date: Date,
        snapshot: WidgetSnapshot?,
        hasSnapshot: Bool
    ) -> SingleGameEntry {
        let selectedID = configuration.game?.id
        let state = resolveState(selectedID: selectedID, snapshot: snapshot)
        let resolvedID = selectedID ?? state?.gameId
        let game = resolvedID.flatMap { candidate in
            Game.allAvailableGames.first { $0.id == candidate }
        }
        return SingleGameEntry(date: date, game: game, state: state, hasSnapshot: hasSnapshot)
    }

    /// An unconfigured widget shows whatever needs attention most, so it is
    /// useful the moment it is dropped on the Home Screen.
    private func resolveState(selectedID: UUID?, snapshot: WidgetSnapshot?) -> WidgetGameEntry? {
        guard let snapshot else {
            return nil
        }
        guard let selectedID else {
            return snapshot.mostUrgentGame
        }
        return snapshot.game(withID: selectedID)
    }
}
