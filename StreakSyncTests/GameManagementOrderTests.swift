//
//  GameManagementOrderTests.swift
//  StreakSync
//
//  The Manage Games order that the Dashboard's "My Order" sort renders.
//

import Foundation
@testable import StreakSync
import XCTest

@MainActor
final class GameManagementOrderTests: XCTestCase {
    private let games = Array(Game.allAvailableGames.prefix(4))

    func testNoSavedOrderKeepsCatalogOrder() {
        let state = GameManagementState()
        state.gameOrder = []

        XCTAssertEqual(state.orderedGames(from: games).map(\.id), games.map(\.id))
    }

    func testSavedOrderIsApplied() {
        let state = GameManagementState()
        let reversed = games.reversed().map(\.id)
        state.gameOrder = reversed

        XCTAssertEqual(state.orderedGames(from: games).map(\.id), reversed)
    }

    /// A game added to the catalog after the user last reordered has no saved position; it
    /// must land after every arranged game rather than displacing one of them.
    func testGamesMissingFromTheSavedOrderGoLast() throws {
        let state = GameManagementState()
        let newcomer = try XCTUnwrap(games.first)
        let arranged = games.dropFirst().reversed().map(\.id)
        state.gameOrder = arranged

        let ordered = state.orderedGames(from: games).map(\.id)

        XCTAssertEqual(Array(ordered.prefix(arranged.count)), arranged)
        XCTAssertEqual(ordered.last, newcomer.id)
    }
}
