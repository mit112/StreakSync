//
//  PendingScoreQueueTests.swift
//  StreakSyncTests
//
//  Pins the pending-score retry queue against dropping and against duplicating.
//

@testable import StreakSync
import XCTest

final class PendingScoreQueueTests: XCTestCase {

    private func score(_ dateInt: Int, game: UUID = UUID(), user: String = "me") -> DailyGameScore {
        DailyGameScore(
            id: "\(user)|\(dateInt)|\(game.uuidString)",
            userId: user,
            dateInt: dateInt,
            gameId: game,
            gameName: "Wordle",
            score: 3,
            maxAttempts: 6,
            completed: true,
            currentStreak: 1
        )
    }

    // MARK: - Success removes only what was committed

    /// The bug that made this file necessary. `publishDailyScores` commits one day's
    /// filtered scores, but the queue can hold a backlog from earlier days that never
    /// committed. The old `removeAll()` deleted that backlog without ever writing it.
    func testSuccessKeepsBacklogThatWasNotPartOfTheCommit() {
        let backlog = [score(20_260_827), score(20_260_828)]
        let today = score(20_260_829)

        let result = PendingScoreQueue.afterSuccess(
            queue: backlog + [today],
            committed: [today]
        )

        XCTAssertEqual(
            result.map(\.id), backlog.map(\.id),
            "Committing today's score must not discard an uncommitted backlog"
        )
    }

    /// The flush awaits its commit, and `publishDailyScores` can append during that
    /// suspension — @MainActor isolation does not stop interleaving across an await.
    /// Those arrivals were never committed, so clearing them loses them.
    func testSuccessKeepsScoresQueuedDuringTheCommit() {
        let flushed = [score(20_260_827)]
        let arrivedMidCommit = score(20_260_829)

        let result = PendingScoreQueue.afterSuccess(
            queue: flushed + [arrivedMidCommit],
            committed: flushed
        )

        XCTAssertEqual(result.map(\.id), [arrivedMidCommit.id])
    }

    func testSuccessClearsTheQueueWhenEverythingWasCommitted() {
        let all = [score(20_260_827), score(20_260_828)]
        XCTAssertTrue(PendingScoreQueue.afterSuccess(queue: all, committed: all).isEmpty)
    }

    /// Identity is the composite key, not object identity, so a re-published score for
    /// the same user/day/game clears the queued one.
    func testSuccessMatchesOnCompositeKeyNotInstance() {
        let game = UUID()
        let queued = score(20_260_829, game: game)
        let equivalent = score(20_260_829, game: game)

        XCTAssertEqual(queued.id, equivalent.id, "precondition: same composite key")
        XCTAssertTrue(PendingScoreQueue.afterSuccess(queue: [queued], committed: [equivalent]).isEmpty)
    }

    // MARK: - Failure queues each score exactly once

    /// The flush attempts scores that are ALREADY queued. Appending the snapshot back
    /// doubled the queue every failure, and because each retry re-appended a now-larger
    /// snapshot, an offline device grew its Keychain queue exponentially.
    func testFailureDoesNotDuplicateScoresAlreadyQueued() {
        let queued = [score(20_260_827), score(20_260_828)]

        let result = PendingScoreQueue.afterFailure(queue: queued, attempted: queued)

        XCTAssertEqual(result.count, 2, "A failed flush must not grow the queue")
        XCTAssertEqual(result.map(\.id), queued.map(\.id))
    }

    /// Repeated failures must stay flat, which is the property that actually protects
    /// an offline device.
    func testRepeatedFailuresDoNotGrowTheQueue() {
        let queued = [score(20_260_827), score(20_260_828)]
        var queue = queued

        for _ in 0..<5 {
            queue = PendingScoreQueue.afterFailure(queue: queue, attempted: queue)
        }

        XCTAssertEqual(queue.count, 2, "Five failed retries must leave two scores, not sixty-four")
    }

    /// `publishDailyScores` attempts scores that are NOT yet queued, so its failure
    /// path must still enqueue them. Same helper, opposite input.
    func testFailureQueuesScoresThatWereNotAlreadyQueued() {
        let backlog = [score(20_260_827)]
        let fresh = score(20_260_829)

        let result = PendingScoreQueue.afterFailure(queue: backlog, attempted: [fresh])

        XCTAssertEqual(result.map(\.id), backlog.map(\.id) + [fresh.id])
    }

    func testFailureWithMixedOverlapQueuesEachScoreOnce() {
        let shared = score(20_260_828)
        let backlog = [score(20_260_827), shared]
        let fresh = score(20_260_829)

        let result = PendingScoreQueue.afterFailure(queue: backlog, attempted: [shared, fresh])

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(Set(result.map(\.id)).count, 3, "no duplicates")
    }
}
