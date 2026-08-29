//
//  AppState+DataArchive.swift
//  StreakSync
//
//  Non-destructive account-switch handover: archive the outgoing session's data
//

import Foundation

extension AppState {
    /// Clears in-memory state and archives the on-disk stores under `namespace`
    /// instead of deleting them.
    ///
    /// The counterpart to `clearAllData()`, used on an account switch. Wiping was the
    /// irreversible half of a bug that has no reliable detector: signing in with a
    /// provider the user has never used mints a fresh, empty Firebase account, and the
    /// app read that as an ordinary account switch. With the data archived, signing
    /// back in with the original provider restores it — see `restoreArchivedData`.
    func archiveAllData(namespace: String) async {
        // Archive first, straight off disk, so the backup is taken from the real data
        // and no in-flight save can write cleared state over it.
        persistenceService.archiveAll(namespace: namespace)

        setRecentResults([])
        deletedResultIds.removeAll()
        _tieredAchievements = AchievementFactory.createDefaultAchievements()
        setStreaks(games.map { GameStreak.empty(for: $0) })
        gameResultsCache.removeAll()
        invalidateCache()

        logger.info("Archived app data for the outgoing session")
    }

    /// Moves a previously archived session back into the live stores. Returns true when
    /// something was restored, in which case the caller should reload.
    @discardableResult
    func restoreArchivedData(namespace: String) -> Bool {
        guard persistenceService.hasArchive(namespace: namespace) else { return false }
        let restored = persistenceService.restoreArchive(namespace: namespace)
        if restored {
            logger.info("Restored archived app data for a returning account")
        }
        return restored
    }
}
