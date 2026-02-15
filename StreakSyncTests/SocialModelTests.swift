//
//  SocialModelTests.swift
//  StreakSyncTests
//
//  Tests for social model logic: UserProfile, Friendship, DailyGameScore, Date extensions.
//

import XCTest
@testable import StreakSync

final class SocialModelTests: XCTestCase {

    // MARK: - UserProfile

    func testIsAnonymous_nilProvider() {
        let profile = UserProfile(
            id: "uid1", displayName: "Test",
            authProvider: nil, photoURL: nil, friendCode: nil,
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertTrue(profile.isAnonymous)
    }

    func testIsAnonymous_anonymousProvider() {
        let profile = UserProfile(
            id: "uid1", displayName: "Test",
            authProvider: "anonymous", photoURL: nil, friendCode: nil,
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertTrue(profile.isAnonymous)
    }

    func testIsAnonymous_appleProvider() {
        let profile = UserProfile(
            id: "uid1", displayName: "Test",
            authProvider: "apple", photoURL: nil, friendCode: nil,
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertFalse(profile.isAnonymous)
    }

    func testUserProfileHashable() {
        let p1 = UserProfile(id: "uid1", displayName: "A", authProvider: nil, photoURL: nil, friendCode: nil, createdAt: Date(), updatedAt: Date())
        let p2 = UserProfile(id: "uid1", displayName: "B", authProvider: "apple", photoURL: nil, friendCode: nil, createdAt: Date(), updatedAt: Date())
        // Same id should hash the same if Hashable uses all fields — this tests conformance exists
        let set: Set<UserProfile> = [p1, p2]
        XCTAssertTrue(set.count >= 1, "UserProfile should be Hashable")
    }

    // MARK: - Friendship

    func testOtherUserId_asSender() {
        let f = Friendship(id: "f1", userId1: "alice", userId2: "bob", status: .accepted, createdAt: Date(), senderDisplayName: nil)
        XCTAssertEqual(f.otherUserId(me: "alice"), "bob")
    }

    func testOtherUserId_asReceiver() {
        let f = Friendship(id: "f1", userId1: "alice", userId2: "bob", status: .accepted, createdAt: Date(), senderDisplayName: nil)
        XCTAssertEqual(f.otherUserId(me: "bob"), "alice")
    }

    func testFriendshipStatus_pending() {
        let f = Friendship(id: "f1", userId1: "a", userId2: "b", status: .pending, createdAt: Date(), senderDisplayName: "Alice")
        XCTAssertEqual(f.status, .pending)
        XCTAssertEqual(f.senderDisplayName, "Alice")
    }

    func testFriendshipStatus_accepted() {
        let f = Friendship(id: "f1", userId1: "a", userId2: "b", status: .accepted, createdAt: Date(), senderDisplayName: nil)
        XCTAssertEqual(f.status, .accepted)
    }

    func testFriendshipStatusRawValue() {
        XCTAssertEqual(FriendshipStatus.pending.rawValue, "pending")
        XCTAssertEqual(FriendshipStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(FriendshipStatus(rawValue: "pending"), .pending)
        XCTAssertEqual(FriendshipStatus(rawValue: "accepted"), .accepted)
        XCTAssertNil(FriendshipStatus(rawValue: "rejected"))
    }

    // MARK: - DailyGameScore

    func testDailyGameScoreIdentity() {
        let s1 = DailyGameScore(id: "u1|20250101|g1", userId: "u1", dateInt: 20250101, gameId: Game.wordle.id, gameName: "Wordle", score: 3, maxAttempts: 6, completed: true, currentStreak: 5)
        let s2 = DailyGameScore(id: "u1|20250101|g1", userId: "u1", dateInt: 20250101, gameId: Game.wordle.id, gameName: "Wordle", score: 3, maxAttempts: 6, completed: true, currentStreak: 5)
        XCTAssertEqual(s1, s2, "Same id should be equal")
        XCTAssertEqual(s1.hashValue, s2.hashValue)
    }

    func testDailyGameScoreCodable() throws {
        let original = DailyGameScore(id: "u|20250215|g", userId: "u", dateInt: 20250215, gameId: Game.wordle.id, gameName: "Wordle", score: 4, maxAttempts: 6, completed: true, currentStreak: 10)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DailyGameScore.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.dateInt, 20250215)
        XCTAssertEqual(decoded.score, 4)
        XCTAssertEqual(decoded.currentStreak, 10)
    }

    func testDailyGameScore_nilOptionals() {
        let score = DailyGameScore(id: "u|d|g", userId: "u", dateInt: 20250101, gameId: UUID(), gameName: "Test", score: nil, maxAttempts: 0, completed: false, currentStreak: nil)
        XCTAssertNil(score.score)
        XCTAssertNil(score.currentStreak)
        XCTAssertFalse(score.completed)
    }

    // MARK: - LeaderboardRow

    func testLeaderboardRowIdentity() {
        let row = LeaderboardRow(id: "u1", userId: "u1", displayName: "Alice", totalPoints: 15, perGameBreakdown: [:], perGameStreak: [:])
        XCTAssertEqual(row.id, "u1")
        XCTAssertEqual(row.displayName, "Alice")
        XCTAssertEqual(row.totalPoints, 15)
    }

    // MARK: - Date.utcYYYYMMDD

    func testUTCDateInt_knownDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = DateComponents(year: 2026, month: 2, day: 15)
        let date = cal.date(from: comps)!
        XCTAssertEqual(date.utcYYYYMMDD, 20260215)
    }

    func testUTCDateInt_newYearsDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = DateComponents(year: 2025, month: 1, day: 1)
        let date = cal.date(from: comps)!
        XCTAssertEqual(date.utcYYYYMMDD, 20250101)
    }

    func testUTCDateInt_endOfYear() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = DateComponents(year: 2025, month: 12, day: 31)
        let date = cal.date(from: comps)!
        XCTAssertEqual(date.utcYYYYMMDD, 20251231)
    }

    // MARK: - ScoringModel

    func testScoringModelRawValues() {
        XCTAssertEqual(ScoringModel.lowerAttempts.rawValue, "lowerAttempts")
        XCTAssertEqual(ScoringModel.lowerTimeSeconds.rawValue, "lowerTimeSeconds")
        XCTAssertEqual(ScoringModel.lowerGuesses.rawValue, "lowerGuesses")
        XCTAssertEqual(ScoringModel.lowerHints.rawValue, "lowerHints")
        XCTAssertEqual(ScoringModel.higherIsBetter.rawValue, "higherIsBetter")
    }

    func testScoringModelCodable() throws {
        let original = ScoringModel.lowerTimeSeconds
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScoringModel.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
