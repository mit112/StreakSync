//
//  VerifiedDisplayBugTests.swift
//  StreakSyncTests
//
//  Pins three display defects that shipped: two always-wrong, one silently discarded.
//

@testable import StreakSync
import XCTest

final class VerifiedDisplayBugTests: XCTestCase {

    // MARK: - At-risk remainder count

    /// The bug: `names` listed three games but the remainder subtracted two, so five
    /// at-risk games read "A, B, C, and 3 more" when only two were unlisted.
    func testRemainderCountsGamesNotNamed() {
        let subtitle = AtRiskTodaySection.subtitle(
            for: ["Wordle", "Connections", "Strands", "Pips", "Nerdle"]
        )
        XCTAssertEqual(subtitle, "Wordle, Connections, Strands, and 2 more")
    }

    func testExactlyOneOverTheLimitReadsAsOneMore() {
        let subtitle = AtRiskTodaySection.subtitle(for: ["A", "B", "C", "D"])
        XCTAssertEqual(subtitle, "A, B, C, and 1 more")
    }

    /// At or under the limit there is no remainder clause at all.
    func testAtTheLimitHasNoRemainderClause() {
        XCTAssertEqual(AtRiskTodaySection.subtitle(for: ["A", "B", "C"]), "A, B, C")
        XCTAssertEqual(AtRiskTodaySection.subtitle(for: ["A"]), "A")
    }

    /// The named list and the remainder must always agree: every game is either named
    /// or counted, never both and never neither. This is the invariant the off-by-one
    /// broke, stated independently of the exact wording.
    func testEveryGameIsEitherNamedOrCounted() {
        for total in 1...12 {
            let names = (1...total).map { "Game\($0)" }
            let subtitle = AtRiskTodaySection.subtitle(for: names)

            let namedCount = min(total, 3)
            let claimedRemainder: Int
            if let range = subtitle.range(of: ", and "),
               let more = subtitle.range(of: " more") {
                claimedRemainder = Int(subtitle[range.upperBound..<more.lowerBound]) ?? -1
            } else {
                claimedRemainder = 0
            }

            XCTAssertEqual(
                namedCount + claimedRemainder, total,
                "With \(total) at-risk games the subtitle accounts for \(namedCount + claimedRemainder)"
            )
        }
    }

    // MARK: - Pips completion

    /// The bug: both call sites asked `completionStatus.contains("Completed")`, and no
    /// case of `completionStatus` contains that substring — they are "1/3 Complete",
    /// "2/3 Complete", "All Complete" and "Not Started". So the Pips month summary
    /// permanently read "0 completed" and Pips calendar days were never tinted.
    func testCompletionStatusNeverContainsTheSubstringTheCallSitesLookedFor() {
        for completed in 0...3 {
            let group = makeGroup(difficulties: Array(["Easy", "Medium", "Hard"].prefix(completed)))
            XCTAssertFalse(
                group.completionStatus.contains("Completed"),
                "\(group.completionStatus) — string-matching this is why the count was always zero"
            )
        }
    }

    func testHasAnyCompletionIsTrueWheneverADifficultyWasRecorded() {
        XCTAssertTrue(makeGroup(difficulties: ["Easy"]).hasAnyCompletion)
        XCTAssertTrue(makeGroup(difficulties: ["Easy", "Hard"]).hasAnyCompletion)
        XCTAssertTrue(makeGroup(difficulties: ["Easy", "Medium", "Hard"]).hasAnyCompletion)
    }

    func testHasAnyCompletionIsFalseOnlyWhenNothingWasRecorded() {
        XCTAssertFalse(makeGroup(difficulties: []).hasAnyCompletion)
        XCTAssertEqual(makeGroup(difficulties: []).completionStatus, "Not Started")
    }

    // MARK: - AppError no longer leaks a format placeholder

    /// `String(format:)` was being called against strings with no specifier, so the
    /// associated value was silently discarded. Removing those calls is only safe while
    /// the copy stays placeholder-free: if a translator adds `%@` back, it would now
    /// render literally. This is the guard for that.
    func testNoErrorCopyLeaksARawPlaceholder() {
        let errors: [any Error] = [
            AppError.ShareExtensionError.invalidContentType("public.image"),
            AppError.ShareExtensionError.noContent,
            AppError.ParsingError.unsupportedGame(detectedName: "Foo"),
            AppError.ParsingError.missingPuzzleNumber(game: "Wordle")
        ]

        for error in errors {
            let description = (error as? LocalizedError)?.errorDescription ?? ""
            let reason = (error as? LocalizedError)?.failureReason ?? ""
            for text in [description, reason] where !text.isEmpty {
                XCTAssertFalse(text.contains("%@"), "Raw placeholder reached the user: \(text)")
                XCTAssertFalse(text.contains("%d"), "Raw placeholder reached the user: \(text)")
            }
        }
    }

    // MARK: - Helpers

    /// Fixture shape copied from StreakHistoryGroupedDisplayTests. Pips is
    /// `.lowerTimeSeconds`, so `score` is a duration and `maxAttempts` is the cap —
    /// GameResult's initializer asserts this and a wrong shape aborts the test host.
    private func makeGroup(difficulties: [String]) -> GroupedGameResult {
        let results = difficulties.map { difficulty in
            GameResult(
                gameId: Game.pips.id,
                gameName: Game.Names.pips,
                date: Date(),
                score: 120,
                maxAttempts: 600,
                completed: true,
                sharedText: "Pips #42 \(difficulty) 2:00",
                parsedData: [
                    "puzzleNumber": "42",
                    "difficulty": difficulty,
                    "time": "2:00",
                    "totalSeconds": "120"
                ]
            )
        }
        return GroupedGameResult(
            gameId: Game.pips.id,
            gameName: Game.Names.pips,
            puzzleNumber: "42",
            date: results.first?.date ?? Date(),
            results: results
        )
    }
}
