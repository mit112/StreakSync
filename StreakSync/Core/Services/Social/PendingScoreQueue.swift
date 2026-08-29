//
//  PendingScoreQueue.swift
//  StreakSync
//
//  Pure bookkeeping for the Keychain-backed pending-score retry queue.
//

import Foundation

/// Decides what stays queued after a publish attempt.
///
/// Both call sites used to hand-roll this, and both were wrong in the same way: they
/// called `pendingScores.removeAll()` on success, which is only correct when the set
/// just committed happens to be the entire queue. It is not.
///
/// - `publishDailyScores` commits one day's filtered scores while the queue can hold a
///   backlog from earlier days that never committed. `removeAll()` deleted that backlog
///   without ever having written it.
/// - `flushPendingScoresIfNeeded` awaits a commit, and `publishDailyScores` can append
///   during that suspension — `@MainActor` isolation does not prevent interleaving
///   across an `await`. Those newly queued scores were dropped uncommitted too.
///
/// The failure path had the mirror-image bug: it appended a snapshot back onto a queue
/// that still contained it, doubling the queue on every failure.
///
/// Both operations are set arithmetic on `DailyGameScore.id`, which is the composite
/// key `userId|yyyyMMdd|gameId`, so a score is identified by what it is *about* rather
/// than by object identity.
enum PendingScoreQueue {

    /// The queue after `committed` was durably written.
    ///
    /// Removes exactly what was committed and nothing else, so a backlog that was not
    /// part of this commit survives it.
    static func afterSuccess(
        queue: [DailyGameScore],
        committed: [DailyGameScore]
    ) -> [DailyGameScore] {
        let committedIds = Set(committed.map(\.id))
        return queue.filter { !committedIds.contains($0.id) }
    }

    /// The queue after an attempt to write `attempted` failed.
    ///
    /// Everything attempted must end up queued, but only once. Scores already in the
    /// queue stay put; scores that were never queued are appended. This is what makes
    /// one helper correct for both callers: the flush attempts scores that are already
    /// queued, and `publishDailyScores` attempts scores that are not.
    static func afterFailure(
        queue: [DailyGameScore],
        attempted: [DailyGameScore]
    ) -> [DailyGameScore] {
        var queuedIds = Set(queue.map(\.id))
        var result = queue
        for score in attempted where !queuedIds.contains(score.id) {
            result.append(score)
            queuedIds.insert(score.id)
        }
        return result
    }
}
