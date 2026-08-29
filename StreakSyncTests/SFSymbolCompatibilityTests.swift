//
//  SFSymbolCompatibilityTests.swift
//  StreakSyncTests
//
//  Tests for the SF Symbol availability guard and its fallback table.
//

@testable import StreakSync
import UIKit
import XCTest

@MainActor
final class SFSymbolCompatibilityTests: XCTestCase {
    /// A name that is not, and will not become, a real SF Symbol.
    private let missingSymbol = "streaksync.not.a.real.symbol"

    // MARK: - isSymbolAvailable

    func testKnownSymbolIsReportedAvailable() {
        XCTAssertTrue(SFSymbolCompatibility.isSymbolAvailable("star.fill"))
    }

    func testUnknownSymbolIsReportedUnavailable() {
        XCTAssertFalse(SFSymbolCompatibility.isSymbolAvailable(missingSymbol))
    }

    // MARK: - compatibleSymbol

    func testAvailableSymbolIsKeptInsteadOfTheFallback() {
        let resolved = SFSymbolCompatibility.compatibleSymbol("star.fill", fallback: "circle")
        XCTAssertEqual(resolved, "star.fill")
    }

    func testUnavailableSymbolIsReplacedByTheFallback() {
        let resolved = SFSymbolCompatibility.compatibleSymbol(missingSymbol, fallback: "circle")
        XCTAssertEqual(resolved, "circle")
    }

    // MARK: - getSymbol

    /// Without the empty-string guard `getSymbol` would look up "" in the
    /// mapping table, miss, and hand "" back to `Image(systemName:)`.
    func testEmptyNameResolvesToTheQuestionMarkPlaceholder() {
        XCTAssertEqual(SFSymbolCompatibility.getSymbol(""), "questionmark.circle")
    }

    /// The mapping table is a *fallback* table, not a rename table: while the
    /// requested symbol is available it must win over its mapped substitute.
    func testMappedSymbolKeepsItsOwnNameWhileItIsStillAvailable() {
        XCTAssertEqual(SFSymbolCompatibility.getSymbol("star.fill"), "star.fill")
        let chart = SFSymbolCompatibility.getSymbol("chart.line.uptrend.xyaxis")
        XCTAssertEqual(chart, "chart.line.uptrend.xyaxis")
        XCTAssertEqual(SFSymbolCompatibility.getSymbol("trophy.fill"), "trophy.fill")
    }

    func testUnmappedSymbolIsReturnedUnchanged() {
        XCTAssertEqual(SFSymbolCompatibility.getSymbol("gearshape.fill"), "gearshape.fill")
    }

    // MARK: - Fallback table integrity

    /// Whatever `getSymbol` hands back must actually render. This is the test
    /// that catches a fallback entry naming a symbol that does not exist.
    func testEverySymbolTheTableCanReturnIsRenderable() {
        for key in SFSymbolCompatibility.symbolMappings.keys {
            let resolved = SFSymbolCompatibility.getSymbol(key)
            XCTAssertNotNil(UIImage(systemName: resolved), "\(key) resolved to unrenderable \(resolved)")
        }
    }

    func testNoFallbackEntryPointsAtItself() {
        for (symbol, fallback) in SFSymbolCompatibility.symbolMappings {
            XCTAssertNotEqual(symbol, fallback, "\(symbol) falls back to itself, so the entry is a no-op")
        }
    }
}
