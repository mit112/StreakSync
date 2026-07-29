//
//  FriendsPresentationStateTests.swift
//  StreakSyncTests
//
//  Precedence matrix for the single dominant Friends trust state
//

@testable import StreakSync
import XCTest

final class FriendsPresentationStateTests: XCTestCase {
    func testOfflineOverridesErrorSignInAndEmpty() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: true,
            errorMessage: "Server failed",
            isAnonymous: true,
            isLoading: false,
            hasRows: false,
            hasFriends: false,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .offline(showingCachedScores: false))
    }

    func testErrorOverridesSignInAndEmpty() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: "Server failed",
            isAnonymous: true,
            isLoading: false,
            hasRows: false,
            hasFriends: false,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .error(message: "Server failed", showingCachedScores: false))
    }

    func testAnonymousEmptyStateRequestsSignIn() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: nil,
            isAnonymous: true,
            isLoading: false,
            hasRows: false,
            hasFriends: false,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .signInRequired)
    }

    func testSignedInEmptyStateInvitesFriends() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: nil,
            isAnonymous: false,
            isLoading: false,
            hasRows: false,
            hasFriends: true,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .empty)
    }

    func testRowsProducePopulatedState() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: nil,
            isAnonymous: false,
            isLoading: false,
            hasRows: true,
            hasFriends: true,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .populated)
    }

    func testLoadingWithoutRowsProducesLoadingState() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: nil,
            isAnonymous: false,
            isLoading: true,
            hasRows: false,
            hasFriends: false,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .loading)
    }

    func testOfflineWithRowsMarksCachedContent() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: true,
            errorMessage: nil,
            isAnonymous: false,
            isLoading: false,
            hasRows: true,
            hasFriends: true,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .offline(showingCachedScores: true))
    }

    func testErrorWithRowsMarksCachedContent() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: "Server failed",
            isAnonymous: false,
            isLoading: false,
            hasRows: true,
            hasFriends: true,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .error(message: "Server failed", showingCachedScores: true))
    }

    func testEmptyErrorMessageIsNotTreatedAsAnError() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: "",
            isAnonymous: true,
            isLoading: false,
            hasRows: false,
            hasFriends: false,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .signInRequired)
    }

    func testLoadingWithCachedRowsKeepsShowingContent() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: nil,
            isAnonymous: false,
            isLoading: true,
            hasRows: true,
            hasFriends: true,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .populated)
    }

    func testAnonymousWithCachedRowsDoesNotDemandSignIn() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: nil,
            isAnonymous: true,
            isLoading: false,
            hasRows: true,
            hasFriends: false,
            pendingScoreCount: 0
        ))
        XCTAssertEqual(state, .populated)
    }

    func testPendingUploadExplainsAMissingOwnRow() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: nil,
            isAnonymous: false,
            isLoading: false,
            hasRows: false,
            hasFriends: false,
            pendingScoreCount: 1
        ))
        XCTAssertEqual(state, .pendingUpload(count: 1))
    }

    func testPendingUploadOutranksEmptyButNotError() {
        let pending = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: nil,
            isAnonymous: false,
            isLoading: false,
            hasRows: true,
            hasFriends: true,
            pendingScoreCount: 3
        ))
        XCTAssertEqual(pending, .pendingUpload(count: 3))

        let error = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: "Server failed",
            isAnonymous: false,
            isLoading: false,
            hasRows: true,
            hasFriends: true,
            pendingScoreCount: 3
        ))
        XCTAssertEqual(error, .error(message: "Server failed", showingCachedScores: true))
    }

    func testSignInRequirementOutranksPendingUpload() {
        let state = FriendsPresentationState.resolve(.init(
            isOffline: false,
            errorMessage: nil,
            isAnonymous: true,
            isLoading: false,
            hasRows: false,
            hasFriends: false,
            pendingScoreCount: 2
        ))
        XCTAssertEqual(state, .signInRequired)
    }
}
