//
//  SyncServerWatermarkTests.swift
//  StreakSync
//
//  The server-clock watermark behind the serverModified sync query.
//

import Foundation
@testable import StreakSync
import XCTest

final class SyncServerWatermarkTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func testAnEmptyPageKeepsTheWatermark() {
        XCTAssertEqual(SyncServerWatermark.advanced(from: t0, fetched: []), t0)
        XCTAssertNil(SyncServerWatermark.advanced(from: nil, fetched: []))
    }

    func testAdvancesToTheNewestFetchedServerTime() {
        let fetched = [t0.addingTimeInterval(5), t0.addingTimeInterval(30), t0.addingTimeInterval(10)]
        XCTAssertEqual(SyncServerWatermark.advanced(from: t0, fetched: fetched), t0.addingTimeInterval(30))
    }

    /// With no stored watermark the first page sets it outright.
    func testFirstPageSetsTheWatermark() {
        XCTAssertEqual(SyncServerWatermark.advanced(from: nil, fetched: [t0]), t0)
    }

    /// The watermark never moves backwards, even if an older stamp comes back.
    func testNeverMovesBackwards() {
        XCTAssertEqual(SyncServerWatermark.advanced(from: t0, fetched: [t0.addingTimeInterval(-60)]), t0)
    }

    /// A WriteBatch commits up to 500 documents at one server time; a page must be able to
    /// hold more than one such group or the inclusive query could never advance past it.
    func testPageLimitExceedsTheLargestSameTimestampBatch() {
        XCTAssertGreaterThan(SyncServerWatermark.pageLimit, 500)
    }
}
