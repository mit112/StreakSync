//
//  DeepLinkNameMatchingTests.swift
//  StreakSync
//
//  Verifies streaksync://game?name=<X> resolves by slug AND by display name.
//

import Foundation
@testable import StreakSync
import XCTest

@MainActor
final class DeepLinkNameMatchingTests: XCTestCase {
    private let catalog = Game.allAvailableGames

    // MARK: - Slug matching (pre-existing behaviour — must not regress)

    func testSlugNameStillResolves() {
        let game = NotificationCoordinator.resolveGame(named: "minicrossword", in: catalog)
        XCTAssertEqual(game?.id, Game.miniCrossword.id)
    }

    func testSlugNameIsCaseInsensitiveAsBefore() {
        let game = NotificationCoordinator.resolveGame(named: "LinkedInQueens", in: catalog)
        XCTAssertEqual(game?.id, Game.linkedinQueens.id)
    }

    // MARK: - Display-name matching (the widening)

    /// `streaksync://game?name=Mini%20Crossword` percent-decodes to "Mini Crossword",
    /// which matches no `Game.name` slug. Fails against the un-widened matcher.
    func testDisplayNameWithSpaceResolves() {
        let game = NotificationCoordinator.resolveGame(named: "Mini Crossword", in: catalog)
        XCTAssertEqual(game?.id, Game.miniCrossword.id)
    }

    func testDisplayNameIsCaseAndWhitespaceInsensitive() {
        let variants = ["mini crossword", "MINI CROSSWORD", "Mini Crossword", " Mini  Crossword "]
        for variant in variants {
            let game = NotificationCoordinator.resolveGame(named: variant, in: catalog)
            XCTAssertEqual(game?.id, Game.miniCrossword.id, "Failed to resolve '\(variant)'")
        }
    }

    /// LinkedIn games carry a slug that shares no prefix with their display name
    /// ("linkedinqueens" vs "Queens"), so this only passes via the fallback.
    func testLinkedInDisplayNameResolves() {
        let game = NotificationCoordinator.resolveGame(named: "Queens", in: catalog)
        XCTAssertEqual(game?.id, Game.linkedinQueens.id)
    }

    func testSpellingBeeDisplayNameResolves() {
        let game = NotificationCoordinator.resolveGame(named: "Spelling Bee", in: catalog)
        XCTAssertEqual(game?.id, Game.spellingBee.id)
    }

    // MARK: - Misses

    func testUnknownNameResolvesToNil() {
        XCTAssertNil(NotificationCoordinator.resolveGame(named: "Definitely Not A Game", in: catalog))
    }

    func testWhitespaceOnlyNameResolvesToNil() {
        XCTAssertNil(NotificationCoordinator.resolveGame(named: "   ", in: catalog))
    }

    // MARK: - Ambiguity guard

    /// The fallback would silently route to an arbitrary game if two catalog entries
    /// normalised to the same string. Adding such a game must fail here, not in the wild.
    func testNormalizedDisplayNamesAreUnambiguous() {
        let normalized = catalog.map { game in
            game.displayName.lowercased().filter { !$0.isWhitespace }
        }
        XCTAssertEqual(Set(normalized).count, normalized.count, "Colliding display names: \(normalized)")
    }

    /// Every game's own display name must resolve to itself. This is the invariant the
    /// slug-first ordering can break: if game A's slug equalled game B's normalised
    /// display name, the slug pass would hijack B's display name and this would fail.
    func testEveryDisplayNameResolvesToItsOwnGame() {
        for game in catalog {
            let matched = NotificationCoordinator.resolveGame(named: game.displayName, in: catalog)
            XCTAssertEqual(matched?.id, game.id, "'\(game.displayName)' resolved to the wrong game")
        }
    }

    /// Slugs are the pre-existing contract; every one must still resolve to itself.
    func testEverySlugResolvesToItsOwnGame() {
        for game in catalog {
            let matched = NotificationCoordinator.resolveGame(named: game.name, in: catalog)
            XCTAssertEqual(matched?.id, game.id, "Slug '\(game.name)' resolved to the wrong game")
        }
    }
}
