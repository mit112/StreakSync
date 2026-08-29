//
//  SocialNotificationSchedulingTests.swift
//  StreakSyncTests
//
//  Tests for the friend-activity nudge decision: whether to notify, and with what copy.
//

@testable import StreakSync
import XCTest

@MainActor
final class SocialNotificationSchedulingTests: XCTestCase {
    // Stand-ins for catalog entries. The policy only needs UUID keys plus a name lookup,
    // so no Game or GameResult fixture is constructed anywhere in this file.
    private let wordleID = UUID()
    private let connectionsID = UUID()
    private let strandsID = UUID()
    private let miniID = UUID()
    private let retiredID = UUID()

    private var gameNames: [UUID: String] {
        [
            wordleID: "Wordle",
            connectionsID: "Connections",
            strandsID: "Strands",
            miniID: "Mini Crossword"
        ]
    }

    // MARK: - Fixtures

    /// A leaderboard row for `userId` carrying a posted score for each listed game.
    private func row(_ userId: String, games: [UUID]) -> LeaderboardRow {
        var breakdown: [UUID: Int] = [:]
        for gameID in games {
            breakdown[gameID] = 4
        }
        return LeaderboardRow(
            id: userId,
            userId: userId,
            displayName: userId,
            totalPoints: breakdown.values.reduce(0, +),
            perGameBreakdown: breakdown,
            perGameStreak: [:],
            perGameRawScore: [:]
        )
    }

    /// The baseline eligible situation: two friends played Wordle, the user has not
    /// played, no streak reminder is pending, and no nudge has ever been sent.
    private func makeInput(
        isEnabled: Bool = true,
        friendUserIds: Set<String> = ["friendA", "friendB"],
        leaderboard: [LeaderboardRow]? = nil,
        userPlayedToday: Bool = false,
        streakReminderPending: Bool = false,
        lastNudgeAt: Date? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FriendActivityNudgeInput {
        FriendActivityNudgeInput(
            isEnabled: isEnabled,
            friendUserIds: friendUserIds,
            todaysLeaderboard: leaderboard ?? twoFriendsPlayedWordle,
            gameNamesById: gameNames,
            userPlayedToday: userPlayedToday,
            streakReminderPending: streakReminderPending,
            lastNudgeAt: lastNudgeAt,
            now: now,
            calendar: calendar
        )
    }

    private var twoFriendsPlayedWordle: [LeaderboardRow] {
        [row("friendA", games: [wordleID]), row("friendB", games: [wordleID])]
    }

    private func fixedCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        return calendar
    }

    private func august(_ day: Int, hour: Int, calendar: Calendar) throws -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0
        components.timeZone = calendar.timeZone
        return try XCTUnwrap(calendar.date(from: components))
    }

    // MARK: - The eligible case (positive control for every gate below)

    func testNudgesWhenTwoFriendsPlayedAndUserHasNot() throws {
        let decision = try XCTUnwrap(FriendActivityNudgePolicy.decide(makeInput()))

        XCTAssertEqual(decision.friendCount, 2)
        XCTAssertEqual(decision.gameNames, ["Wordle"])
        XCTAssertEqual(decision.title, "Friends are playing")
        XCTAssertEqual(decision.body, "2 friends have played today — Wordle")
    }

    // MARK: - Eligibility gates

    func testTurnedOffSchedulesNothing() {
        XCTAssertNil(FriendActivityNudgePolicy.decide(makeInput(isEnabled: false)))
    }

    func testNoFriendsSchedulesNothing() {
        XCTAssertNil(FriendActivityNudgePolicy.decide(makeInput(friendUserIds: [])))
    }

    func testUserAlreadyPlayedSchedulesNothing() {
        XCTAssertNil(FriendActivityNudgePolicy.decide(makeInput(userPlayedToday: true)))
    }

    func testPendingStreakReminderSchedulesNothing() {
        // The streak reminder already covers tonight; two notifications is the failure
        // mode this gate exists to prevent.
        XCTAssertNil(FriendActivityNudgePolicy.decide(makeInput(streakReminderPending: true)))
    }

    func testNoFriendActivitySchedulesNothing() {
        XCTAssertNil(FriendActivityNudgePolicy.decide(makeInput(leaderboard: [])))
    }

    func testSingleFriendIsBelowTheThreshold() {
        let leaderboard = [row("friendA", games: [wordleID])]
        XCTAssertNil(FriendActivityNudgePolicy.decide(makeInput(leaderboard: leaderboard)))
    }

    func testOwnRowAndNonFriendRowsDoNotCountTowardTheThreshold() {
        // Only friendA is a friend; "me" and "stranger" are visible on the leaderboard
        // (self, plus a former friend still in an allowedReaders array) but must not
        // push the count to the two-friend threshold.
        let leaderboard = [
            row("me", games: [wordleID]),
            row("stranger", games: [wordleID]),
            row("friendA", games: [wordleID])
        ]
        let input = makeInput(friendUserIds: ["friendA"], leaderboard: leaderboard)
        XCTAssertNil(FriendActivityNudgePolicy.decide(input))
    }

    func testFriendWithNoPostedScoreDoesNotCount() {
        let leaderboard = [row("friendA", games: [wordleID]), row("friendB", games: [])]
        XCTAssertNil(FriendActivityNudgePolicy.decide(makeInput(leaderboard: leaderboard)))
    }

    // MARK: - Frequency

    func testPolicyConstants() {
        XCTAssertEqual(FriendActivityNudgePolicy.minimumFriendsWhoPlayed, 2)
        XCTAssertEqual(FriendActivityNudgePolicy.minimumDaysBetweenNudges, 3)
        XCTAssertGreaterThanOrEqual(
            FriendActivityNudgePolicy.minimumDaysBetweenNudges, 1,
            "The nudge must never be able to fire more than once in a day"
        )
    }

    func testSecondNudgeOnTheSameDayIsBlocked() throws {
        let calendar = try fixedCalendar()
        let lastNudge = try august(29, hour: 8, calendar: calendar)
        let now = try august(29, hour: 19, calendar: calendar)

        let input = makeInput(lastNudgeAt: lastNudge, now: now, calendar: calendar)
        XCTAssertNil(FriendActivityNudgePolicy.decide(input))
    }

    func testNudgeTwoDaysAfterTheLastOneIsBlocked() throws {
        let calendar = try fixedCalendar()
        let lastNudge = try august(27, hour: 19, calendar: calendar)
        let now = try august(29, hour: 19, calendar: calendar)

        let input = makeInput(lastNudgeAt: lastNudge, now: now, calendar: calendar)
        XCTAssertNil(FriendActivityNudgePolicy.decide(input))
    }

    func testNudgeThreeDaysAfterTheLastOneIsAllowed() throws {
        let calendar = try fixedCalendar()
        let lastNudge = try august(26, hour: 19, calendar: calendar)
        let now = try august(29, hour: 19, calendar: calendar)

        let input = makeInput(lastNudgeAt: lastNudge, now: now, calendar: calendar)
        XCTAssertNotNil(FriendActivityNudgePolicy.decide(input))
    }

    func testCooldownCountsCalendarDaysNotElapsedTime() throws {
        // 26th 23:00 → 29th 00:30 is 2 days and 1.5 hours of elapsed time but three
        // calendar days. Comparing raw intervals against 3 × 86400 would say "not yet".
        let calendar = try fixedCalendar()
        let last = try august(26, hour: 23, calendar: calendar)
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 29
        components.hour = 0
        components.minute = 30
        components.timeZone = calendar.timeZone
        let now = try XCTUnwrap(calendar.date(from: components))

        XCTAssertLessThan(now.timeIntervalSince(last), 3 * 86_400)
        XCTAssertTrue(
            FriendActivityNudgePolicy.isPastCooldown(lastNudgeAt: last, now: now, calendar: calendar)
        )
    }

    func testFirstEverNudgeHasNoCooldown() throws {
        let calendar = try fixedCalendar()
        let now = try august(29, hour: 19, calendar: calendar)
        XCTAssertTrue(
            FriendActivityNudgePolicy.isPastCooldown(lastNudgeAt: nil, now: now, calendar: calendar)
        )
    }

    // MARK: - Copy

    func testBodyNamesUpToThreeGames() {
        // All three are tied at two friends each, so they fall back to name order.
        let leaderboard = [
            row("friendA", games: [wordleID, connectionsID, strandsID]),
            row("friendB", games: [wordleID, connectionsID, strandsID])
        ]
        let decision = FriendActivityNudgePolicy.decide(makeInput(leaderboard: leaderboard))

        XCTAssertEqual(decision?.gameNames, ["Connections", "Strands", "Wordle"])
        XCTAssertEqual(decision?.body, "2 friends have played today — Connections, Strands, Wordle")
    }

    func testBodyCollapsesTheFourthGameAndBeyond() {
        let allFour = [wordleID, connectionsID, strandsID, miniID]
        let leaderboard = [
            row("friendA", games: allFour),
            row("friendB", games: allFour)
        ]
        let decision = FriendActivityNudgePolicy.decide(makeInput(leaderboard: leaderboard))

        XCTAssertEqual(
            decision?.body,
            "2 friends have played today — Connections, Mini Crossword, and 2 other games"
        )
    }

    func testGamesAreOrderedByHowManyFriendsPlayedThem() {
        // Two friends on Connections, one on Wordle — Connections must lead even though
        // "Connections" sorts after "Wordle" is inserted first.
        let leaderboard = [
            row("friendA", games: [connectionsID, wordleID]),
            row("friendB", games: [connectionsID])
        ]
        let decision = FriendActivityNudgePolicy.decide(makeInput(leaderboard: leaderboard))

        XCTAssertEqual(decision?.gameNames, ["Connections", "Wordle"])
        XCTAssertEqual(decision?.body, "2 friends have played today — Connections, Wordle")
    }

    func testTiedGameCountsAreOrderedByName() {
        let leaderboard = [
            row("friendA", games: [wordleID, connectionsID]),
            row("friendB", games: [wordleID, connectionsID])
        ]
        let decision = FriendActivityNudgePolicy.decide(makeInput(leaderboard: leaderboard))

        XCTAssertEqual(decision?.gameNames, ["Connections", "Wordle"])
    }

    func testUnknownGameStillCountsTheFriendButIsNotNamed() {
        // A retired game that is no longer in the catalog has no display name to print,
        // but the friends who played it still played today.
        let leaderboard = [
            row("friendA", games: [retiredID]),
            row("friendB", games: [retiredID])
        ]
        let decision = FriendActivityNudgePolicy.decide(makeInput(leaderboard: leaderboard))

        XCTAssertEqual(decision?.friendCount, 2)
        XCTAssertEqual(decision?.gameNames, [])
        XCTAssertEqual(decision?.body, "2 friends have played today")
    }

    func testBodyIsSingularForOneFriend() {
        XCTAssertEqual(
            FriendActivityNudgePolicy.makeBody(friendCount: 1, gameNames: ["Wordle"]),
            "1 friend has played today — Wordle"
        )
    }

    // MARK: - Settings default

    func testEnabledDefaultsToOnWhenTheKeyWasNeverWritten() throws {
        let suiteName = "SocialNotificationSchedulingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertTrue(FriendActivityNudgePolicy.isEnabled(defaults: defaults))
    }

    func testEnabledRespectsAnExplicitOptOut() throws {
        let suiteName = "SocialNotificationSchedulingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: AppConstants.NotificationSettings.friendActivityNudgeEnabled)

        XCTAssertFalse(FriendActivityNudgePolicy.isEnabled(defaults: defaults))
    }

    // MARK: - Notification payload

    func testFriendActivityCategoryIdentifier() {
        XCTAssertEqual(NotificationCategory.friendActivity.identifier, "FRIEND_ACTIVITY")
    }

    func testBuiltContentCarriesCopyCategoryAndRoutingType() throws {
        let nudge = try XCTUnwrap(FriendActivityNudgePolicy.decide(makeInput()))
        let content = NotificationScheduler.shared.buildFriendActivityContent(nudge)

        XCTAssertEqual(content.title, "Friends are playing")
        XCTAssertEqual(content.body, "2 friends have played today — Wordle")
        XCTAssertEqual(content.categoryIdentifier, NotificationCategory.friendActivity.identifier)
        XCTAssertEqual(content.userInfo["type"] as? String, "friend_activity")
        XCTAssertNil(content.userInfo["gameId"])
        XCTAssertNotNil(content.sound)
    }

    func testNudgeIdentifierIsFixedSoOnlyOneCanEverBePending() {
        XCTAssertEqual(NotificationScheduler.friendActivityNudgeIdentifier, "friend_activity_nudge")
    }
}
