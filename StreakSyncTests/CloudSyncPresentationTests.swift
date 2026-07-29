//
//  CloudSyncPresentationTests.swift
//  StreakSyncTests
//
//  Anonymous/signed-in cloud-sync availability visibility
//

@testable import StreakSync
import XCTest

final class CloudSyncPresentationTests: XCTestCase {
    func testAnonymousUserSeesOnlySignInRequirement() {
        let state = CloudSyncPresentation.resolve(isAnonymous: true)
        XCTAssertEqual(state, .signInRequired)
        XCTAssertFalse(state.showsSyncControls)
        XCTAssertFalse(state.showsSyncStatuses)
    }

    func testSignedInUserSeesControlsAndStatuses() {
        let state = CloudSyncPresentation.resolve(isAnonymous: false)
        XCTAssertEqual(state, .available)
        XCTAssertTrue(state.showsSyncControls)
        XCTAssertTrue(state.showsSyncStatuses)
    }
}
