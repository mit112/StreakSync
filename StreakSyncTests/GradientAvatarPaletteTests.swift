//
//  GradientAvatarPaletteTests.swift
//  StreakSyncTests
//
//  Regression tests for bug B3: avatar gradient must be stable across launches.
//

@testable import StreakSync
import XCTest

final class GradientAvatarPaletteTests: XCTestCase {
    func testPaletteIndexIsDeterministicAcrossCalls() {
        // Same key must always map to the same palette. String.hashValue is
        // randomized per process, so the old code recolored avatars every launch.
        let first = GradientAvatar.paletteIndex(for: "Alex", count: 5)
        let second = GradientAvatar.paletteIndex(for: "Alex", count: 5)
        XCTAssertEqual(first, second)
    }

    func testPaletteIndexKnownValues() {
        // djb2 over UTF-8 bytes, hand-computed and stable.
        XCTAssertEqual(GradientAvatar.paletteIndex(for: "A", count: 5), 3)
        XCTAssertEqual(GradientAvatar.paletteIndex(for: "B", count: 5), 4)
    }

    func testPaletteIndexInRange() {
        for key in ["", "Mit", "Zoë", "12345", "🙂"] {
            let idx = GradientAvatar.paletteIndex(for: key, count: 5)
            XCTAssertTrue((0..<5).contains(idx), "index \(idx) out of range for \(key)")
        }
    }

    func testPaletteIndexHandlesZeroCount() {
        XCTAssertEqual(GradientAvatar.paletteIndex(for: "x", count: 0), 0)
    }
}
