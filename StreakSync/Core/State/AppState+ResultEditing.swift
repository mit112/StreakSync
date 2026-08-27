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

        // 2. Recompute and persist everything derived from the result set
        await reconcileAfterResultSetChanged()

        logger.info("Edited game result for \(edited.gameName) and recomputed state")

        // 3. Published scores are keyed by day, so moving a result to a different date
        // leaves the original day's entry stranded on friends' leaderboards. Retract it
        // before republishing under the new date.
        if original.date.utcYYYYMMDD != edited.date.utcYYYYMMDD {
            retractScoreFromSocial(date: original.date, gameId: original.gameId)
        }

        // 4. Republish social score (best-effort)
        publishScoreToSocial(edited)
    }
}
