//
//  AppState+Reconciliation.swift
//  StreakSync
//
//  Single recompute path for every piece of state derived from `recentResults`
//

import Foundation

extension AppState {
    /// Recomputes everything derived from `recentResults`, then persists and publishes it.
    ///
    /// Call this after ANY wholesale change to the result set that did not go through
    /// `addGameResult` — cloud sync merges, backup imports, pruning, backfilled results.
    /// Those paths used to hand-roll a subset of these steps, and every omission produced
    /// a visible inconsistency: streaks rebuilt but achievements left stale, results saved
    /// but streaks left stale on disk, or the dedup cache still describing the old set.
    ///
    /// The order matters: the dedup cache and streaks must be correct before achievements
    /// are recomputed from them, and the UI is refreshed before the (slower) writes so
    /// views never render a half-updated state.
    func reconcileAfterResultSetChanged() async {
        buildResultsCache()
        recordActiveDays(from: recentResults)
        recordUniqueGames(from: recentResults)

        await rebuildStreaksFromResults()
        await normalizeStreaksForMissedDays()
        recalculateAllTieredAchievementProgress()

        invalidateCache()
        NotificationCenter.default.post(name: .appGameDataUpdated, object: nil)

        await saveGameResults()
        await saveStreaks()
        await saveTieredAchievements()
    }
}
