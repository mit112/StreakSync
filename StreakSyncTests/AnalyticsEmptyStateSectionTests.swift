//
//  AnalyticsEmptyStateSectionTests.swift
//  StreakSyncTests
//
//  Copy shown by the Analytics empty state, per scope.
//

import Foundation
@testable import StreakSync
import XCTest

/// `AnalyticsViewModel` decides *whether* the empty state appears
/// (`hasDataForCurrentSelection`, covered in `AnalyticsViewModelPresentationTests`) and
/// states *what* is missing (`emptyStateMessage`). This suite covers the other half —
/// the heading and the remedy the component itself supplies.
@MainActor
final class AnalyticsEmptyStateSectionTests: XCTestCase {
    private func makeSection(isFilteredToOneGame: Bool) -> AnalyticsEmptyStateSection {
        AnalyticsEmptyStateSection(
            message: "irrelevant to the properties under test",
            isFilteredToOneGame: isFilteredToOneGame,
            onShowAllGames: {}
        )
    }

    // MARK: - Title

    /// A user with a game filter on usually has plenty of results, just not for that
    /// game — telling them "No Results Yet" would be wrong. Collapsing `title` to a
    /// single constant string fails this.
    func test_title_distinguishesAFilteredGameFromAnEmptyAccount() {
        XCTAssertEqual(makeSection(isFilteredToOneGame: false).title, "No Results Yet")
        XCTAssertEqual(makeSection(isFilteredToOneGame: true).title, "No Results for This Game")
    }

    // MARK: - Guidance

    /// The blank-screen bug this empty state exists for: someone who has never recorded
    /// anything needs the share-sheet route spelled out, because nothing in the app can
    /// produce a result for them. Deleting the `if isFilteredToOneGame` branch in
    /// `guidance` — so both scopes return the filter copy — fails this.
    func test_guidance_allGames_explainsHowToRecordAFirstResult() {
        let guidance = makeSection(isFilteredToOneGame: false).guidance

        XCTAssertTrue(guidance.contains("share button"), "Must name the share step: \(guidance)")
        XCTAssertTrue(guidance.contains("StreakSync"), "Must name the extension to pick: \(guidance)")
    }

    /// The game filter lives behind a toolbar menu, so the copy has to say the filter is
    /// what is hiding the data. Returning the All Games copy from the filtered branch
    /// fails this — that copy never mentions showing all games.
    func test_guidance_singleGame_offersTheAllGamesEscapeHatch() {
        let guidance = makeSection(isFilteredToOneGame: true).guidance

        XCTAssertTrue(guidance.contains("show all games"), "Must point at the filter: \(guidance)")
        XCTAssertFalse(
            guidance.contains("share button"),
            "Someone filtering by game has already shared results; don't re-teach the basics"
        )
    }

    /// The time-range picker sits directly above this view and is the one remedy that
    /// applies to both scopes. Dropping "Try a longer time range above" from either
    /// branch of `guidance` fails this.
    func test_guidance_bothScopes_pointAtTheTimeRangePicker() {
        XCTAssertTrue(makeSection(isFilteredToOneGame: false).guidance.contains("longer time range above"))
        XCTAssertTrue(makeSection(isFilteredToOneGame: true).guidance.contains("longer time range above"))
    }
}
