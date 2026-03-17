//
//  NotificationPermissionFlowTests.swift
//  StreakSyncTests
//
//  Tests for first-launch notification prompt gating.
//

import XCTest
@testable import StreakSync

@MainActor
final class NotificationPermissionFlowTests: XCTestCase {
    private let firstLaunchKey = AppConstants.NotificationSettings.firstLaunchPromptShown

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: firstLaunchKey)
        super.tearDown()
    }

    func testShouldShowFirstLaunchPromptReturnsFalseWhenAlreadyShown() async {
        UserDefaults.standard.set(true, forKey: firstLaunchKey)

        let shouldShow = await NotificationPermissionFlowViewModel.shouldShowFirstLaunchPrompt()

        XCTAssertFalse(shouldShow)
    }

    func testMarkFirstLaunchPromptShownPersistsFlag() {
        NotificationPermissionFlowViewModel.markFirstLaunchPromptShown()

        XCTAssertTrue(UserDefaults.standard.bool(forKey: firstLaunchKey))
    }
}
