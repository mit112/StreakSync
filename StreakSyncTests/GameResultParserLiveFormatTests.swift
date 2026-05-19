//
//  GameResultParserLiveFormatTests.swift
//  StreakSyncTests
//
//  Validates parsers against real-world share text fixtures collected from the web.
//

@testable import StreakSync
import XCTest

final class GameResultParserLiveFormatTests: XCTestCase {
    private let parser = GameResultParser()

    func testAllLiveFormatFixturesMatchExpectations() {
        var failures: [String] = []

        for fixture in GameShareFormatFixtures.all {
            do {
                _ = try parser.parse(fixture.shareText, for: fixture.game)
                if !fixture.shouldParse {
                    failures.append("\(fixture.game.displayName)/\(fixture.label): parsed but expected failure")
                }
            } catch {
                if fixture.shouldParse {
                    failures.append("\(fixture.game.displayName)/\(fixture.label): failed to parse — \(error)")
                }
            }
        }

        if !failures.isEmpty {
            XCTFail("Live format gaps (\(failures.count)):\n" + failures.joined(separator: "\n"))
        }
    }

    func testLiveFormatCoverageIncludesAllGames() {
        let coveredGames = Set(GameShareFormatFixtures.all.map { $0.game.id })
        for game in Game.allAvailableGames {
            XCTAssertTrue(
                coveredGames.contains(game.id),
                "Missing live format fixture for \(game.displayName)"
            )
        }
    }
}
