//
//  FriendsViewModelTests.swift
//  StreakSyncTests
//
//  Tests for FriendsViewModel leaderboard date-open behavior.
//

@testable import StreakSync
import XCTest

@MainActor
final class FriendsViewModelTests: XCTestCase {
    private let legacyDateKey = "friends_last_selected_date"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: legacyDateKey)
        super.tearDown()
    }

    func testInitIgnoresLegacyPersistedDateAndStartsToday() {
        let staleDate = Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        UserDefaults.standard.set(staleDate, forKey: legacyDateKey)

        let viewModel = FriendsViewModel(socialService: MockSocialService())

        XCTAssertTrue(Calendar.current.isDateInToday(viewModel.selectedDateUTC))
    }

    func testHandleSelectedDateChangeClampsFutureDateToToday() {
        let viewModel = FriendsViewModel(socialService: MockSocialService())
        viewModel.selectedDateUTC = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()

        viewModel.handleSelectedDateChange()

        XCTAssertTrue(Calendar.current.isDateInToday(viewModel.selectedDateUTC))
    }
}
