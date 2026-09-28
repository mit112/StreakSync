//
//  LegacyDayKeyCleanupTests.swift
//  StreakSync
//
//  Which pre-1.26 UTC-keyed score documents the day-key migration deletes.
//

import Foundation
@testable import StreakSync
import XCTest

final class LegacyDayKeyCleanupTests: XCTestCase {
    private let gameId = UUID()
    private let userId = "u1"

    private func chicago() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Chicago"))
        return calendar
    }

    private func result(on day: Int, hour: Int, calendar: Calendar) throws -> GameResult {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour)))
        return GameResult(
            gameId: gameId, gameName: "testgame", date: date,
            score: 3, maxAttempts: 6, completed: true, sharedText: "Test result"
        )
    }

    private func sinceSeptemberFirst(_ calendar: Calendar) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
    }

    /// 8 pm Central on the 20th is 01:00 UTC on the 21st: the old key filed it a day late.
    func testEveningShareIsRetractedFromTheNextUTCDay() throws {
        let calendar = try chicago()
        let ids = LegacyDayKeyCleanup.documentIDsToRetract(
            userId: userId,
            results: [try result(on: 20, hour: 20, calendar: calendar)],
            since: try sinceSeptemberFirst(calendar),
            calendar: calendar
        )
        XCTAssertEqual(ids, ["u1|20260921|\(gameId.uuidString)"])
    }

    func testMiddayShareHasNothingToRetract() throws {
        let calendar = try chicago()
        let ids = LegacyDayKeyCleanup.documentIDsToRetract(
            userId: userId,
            results: [try result(on: 20, hour: 12, calendar: calendar)],
            since: try sinceSeptemberFirst(calendar),
            calendar: calendar
        )
        XCTAssertEqual(ids, [])
    }

    /// The 20th's evening share and the 21st's own share both name the 21st; that document
    /// is the 21st's real score now and must survive.
    func testDocumentClaimedByAnotherResultIsKept() throws {
        let calendar = try chicago()
        let ids = LegacyDayKeyCleanup.documentIDsToRetract(
            userId: userId,
            results: [
                try result(on: 20, hour: 20, calendar: calendar),
                try result(on: 21, hour: 9, calendar: calendar)
            ],
            since: try sinceSeptemberFirst(calendar),
            calendar: calendar
        )
        XCTAssertEqual(ids, [])
    }

    func testResultsBeforeTheWindowAreIgnored() throws {
        let calendar = try chicago()
        let since = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 25)))
        let ids = LegacyDayKeyCleanup.documentIDsToRetract(
            userId: userId,
            results: [try result(on: 20, hour: 20, calendar: calendar)],
            since: since,
            calendar: calendar
        )
        XCTAssertEqual(ids, [])
    }
}
