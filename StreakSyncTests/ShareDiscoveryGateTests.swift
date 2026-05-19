//
//  ShareDiscoveryGateTests.swift
//  StreakSync
//
//  Tests for the share-discovery decision gate
//

import XCTest
@testable import StreakSync

final class ShareDiscoveryGateTests: XCTestCase {

    // MARK: - shouldShowOnboarding

    func testShouldShowOnboarding_zeroResultsAndUnseen_returnsTrue() {
        XCTAssertTrue(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 0, hasSeen: false))
    }

    func testShouldShowOnboarding_zeroResultsButAlreadySeen_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 0, hasSeen: true))
    }

    func testShouldShowOnboarding_hasResults_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 1, hasSeen: false))
        XCTAssertFalse(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 42, hasSeen: false))
    }

    func testShouldShowOnboarding_hasResultsAndSeen_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldShowOnboarding(resultsCount: 5, hasSeen: true))
    }

    // MARK: - shouldFireCelebration

    func testShouldFireCelebration_firstResultAndUnseen_returnsTrue() {
        XCTAssertTrue(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 0, hasSeen: false, isGuest: false))
    }

    func testShouldFireCelebration_alreadySeen_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 0, hasSeen: true, isGuest: false))
    }

    func testShouldFireCelebration_notFirstResult_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 1, hasSeen: false, isGuest: false))
        XCTAssertFalse(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 10, hasSeen: false, isGuest: false))
    }

    func testShouldFireCelebration_guestMode_returnsFalse() {
        XCTAssertFalse(ShareDiscoveryGate.shouldFireCelebration(preInsertCount: 0, hasSeen: false, isGuest: true))
    }
}
