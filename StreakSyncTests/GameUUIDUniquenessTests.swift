//
//  GameUUIDUniquenessTests.swift
//  StreakSyncTests
//
//  Verifies that every static Game defined in GameDefinitions.swift has a unique UUID.
//  Both Game.allAvailableGames and the full catalog of static properties are checked so
//  that new games can't accidentally reuse an existing ID.
//

@testable import StreakSync
import XCTest

final class GameUUIDUniquenessTests: XCTestCase {
    // MARK: - allAvailableGames

    func testAllAvailableGamesHaveUniqueUUIDs() {
        let games = Game.allAvailableGames
        let ids = games.map(\.id)
        let uniqueIDs = Set(ids)

        XCTAssertEqual(
            ids.count,
            uniqueIDs.count,
            "allAvailableGames contains \(ids.count - uniqueIDs.count) duplicate UUID(s): \(duplicates(in: ids))"
        )
    }

    // MARK: - Full static catalog

    /// All static Game properties declared in GameDefinitions.swift, including games that are
    /// intentionally kept out of allAvailableGames (no parser yet, secondary catalog, etc.).
    private var allDefinedGames: [Game] {
        [
            // Core NYT / featured
            .wordle, .quordle, .nerdle, .pips,
            .connections, .spellingBee, .miniCrossword, .strands,
            // LinkedIn
            .linkedinQueens, .linkedinTango, .linkedinCrossclimb,
            .linkedinPinpoint, .linkedinZip, .linkedinMiniSudoku,
            // Wordle variants
            .octordle,
            // Word games
            .letterboxed, .waffle,
            .mathle, .numberle,
            .worldle, .globle,
            .contexto, .framed,
            .crosswordle, .extendedMiniCrossword, .sudoku,
            .lyricle, .absurdle, .semantle,
            .dordle, .sedecordle, .kilordle, .antiwordle,
            .wordscapes, .wordhurdle, .xordle, .squareword, .phrazle,
            // Math / logic
            .primel, .ooodle, .summle, .timeguessr, .rankdle,
            // Music / audio
            .songlio, .binb, .songle, .bandle, .musicle,
            // Geography
            .countryle, .flagle, .statele, .citydle, .wheretaken,
            // Trivia / visual
            .moviedle, .posterdle, .actorle, .foodguessr, .artdle
        ]
    }

    func testAllDefinedGamesHaveUniqueUUIDs() {
        let ids = allDefinedGames.map(\.id)
        let uniqueIDs = Set(ids)

        XCTAssertEqual(
            ids.count,
            uniqueIDs.count,
            "Static game catalog contains \(ids.count - uniqueIDs.count) duplicate UUID(s): \(duplicates(in: ids))"
        )
    }

    // MARK: - Helpers

    private func duplicates(in ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var dupes = Set<UUID>()
        for id in ids {
            if seen.contains(id) {
                dupes.insert(id)
            } else {
                seen.insert(id)
            }
        }
        return Array(dupes)
    }
}
