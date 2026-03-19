//
//  AppState+ResultEditing.swift
//  StreakSync
//
//  Edit an existing game result and recompute all dependent state.
//

import Foundation

extension AppState {

    /// Replaces `original` with `edited` (same id) and recomputes streaks,
    /// achievements, caches, and social scores.
    func editGameResult(original: GameResult, edited: GameResult) async {
        guard !isGuestMode else {
            logger.warning("Guest Mode active — skipping editGameResult")
            return
        }

        guard edited.isValid else {
            logger.warning("Edited result is invalid — aborting edit")
            return
        }

        guard original.id == edited.id else {
            logger.error("Edited result id does not match original — aborting edit")
            return
        }

        // 1. Replace in-place (or append if somehow missing)
        replaceOrAppendResult(edited)

        // 2. Rebuild duplicate-prevention cache
        buildResultsCache()

        // 3. Rebuild streaks from scratch
        await rebuildStreaksFromResults()
        await normalizeStreaksForMissedDays()

        // 4. Recheck achievements
        recalculateAllTieredAchievementProgress()

        // 5. Invalidate UI caches
        invalidateCache()

        // 6. Notify UI
        NotificationCenter.default.post(name: .appGameDataUpdated, object: nil)

        // 7. Persist everything
        await saveGameResults()
        await saveStreaks()
        await saveTieredAchievements()

        logger.info("Edited game result for \(edited.gameName) and recomputed state")

        // 8. Republish social score (best-effort)
        if !isGuestMode {
            publishScoreToSocial(edited)
        }
    }
}
