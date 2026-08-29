//
//  SocialWriteFailureTests.swift
//  StreakSyncTests
//
//  Deferred friend-write rejections: alert copy, rollback policy, and the notification payload.
//

import FirebaseFirestore
@testable import StreakSync
import XCTest

/// Interactive friend writes are fired without awaiting the server acknowledgement, because a
/// Firestore write never returns while the client is offline. The whole point of keeping the
/// completion handler is that a rejection still reaches the user — these tests pin the three
/// pieces of that: what the alert says, what the sheet undoes, and what crosses the wire.
final class SocialWriteFailureTests: XCTestCase {
    private func firestoreError(_ code: FirestoreErrorCode.Code) -> NSError {
        NSError(domain: FirestoreErrorDomain, code: code.rawValue)
    }

    // MARK: - Message

    /// By the time a rejection lands the user has already seen the optimistic result, so a
    /// generic "something went wrong" leaves them guessing which of four taps to redo.
    func testMessageNamesTheOperationThatFailed() {
        let accept = SocialWriteFailure(
            operation: .acceptFriendRequest, error: firestoreError(.permissionDenied)
        )
        let remove = SocialWriteFailure(
            operation: .removeFriend, error: firestoreError(.permissionDenied)
        )
        XCTAssertTrue(
            accept.message.hasPrefix(SocialWriteOperation.acceptFriendRequest.failureHeadline)
        )
        XCTAssertNotEqual(accept.message, remove.message)
    }

    /// The reason the completion handler is kept rather than dropped: a rules rejection has to
    /// say *why*, or fire-and-forget is just a silent failure with extra steps.
    func testMessageCarriesTheServerReason() {
        let failure = SocialWriteFailure(
            operation: .sendFriendRequest, error: firestoreError(.permissionDenied)
        )
        let reason = FirebaseSocialError.permissionDenied.errorDescription ?? ""
        XCTAssertFalse(reason.isEmpty)
        XCTAssertTrue(failure.message.hasSuffix(reason))
    }

    /// Not every rejection is a Firestore status code. An error the classifier doesn't
    /// recognise must still explain itself instead of collapsing to a bare headline.
    func testNonFirestoreErrorStillCarriesItsUnderlyingReason() {
        let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let failure = SocialWriteFailure(operation: .removeFriend, error: underlying)
        XCTAssertTrue(failure.message.contains(underlying.localizedDescription))
    }

    // MARK: - Rollback

    /// `addFriendByCode` shows "Friend request sent to X!" in green before the write is
    /// acknowledged. Leaving that line up next to the error alert tells the user two opposite
    /// things at once.
    func testRejectedFriendRequestClearsTheSuccessMessage() {
        XCTAssertEqual(SocialWriteOperation.sendFriendRequest.rollback, .clearSuccessMessage)
    }

    /// The friend code is generated on-device and displayed before the `friendCodes` mirror
    /// document is written. If that write is rejected the code is dead — nobody can redeem it —
    /// so the sheet must forget it rather than let the user share it.
    func testRejectedFriendCodeIsForgotten() {
        XCTAssertEqual(SocialWriteOperation.generateFriendCode.rollback, .forgetFriendCode)
    }

    /// Accept and remove only ever change rows, and Firestore reverts its own local mutation
    /// before it tells us, so re-reading friends and pending requests is the entire rollback.
    func testRowOnlyOperationsRollBackByReloading() {
        XCTAssertEqual(SocialWriteOperation.acceptFriendRequest.rollback, .reloadOnly)
        XCTAssertEqual(SocialWriteOperation.removeFriend.rollback, .reloadOnly)
    }

    // MARK: - Notification payload

    /// The poster (`FirebaseSocialService`) and the observer (`FriendManagementView`) live in
    /// different files and agree only through this payload. Drop either key and the alert
    /// silently never appears — the exact silent failure this design exists to avoid.
    func testUserInfoRoundTripPreservesOperationAndMessage() {
        let sent = SocialWriteFailure(
            operation: .acceptFriendRequest, error: firestoreError(.permissionDenied)
        )
        XCTAssertEqual(SocialWriteFailure(userInfo: sent.notificationUserInfo), sent)
    }

    /// The sheet presents its alert on `errorMessage != nil`, so an empty message would put a
    /// blank alert on screen with an OK button and no explanation.
    func testEmptyMessageIsRejectedRatherThanShownAsABlankAlert() {
        let userInfo: [AnyHashable: Any] = [
            SocialWriteFailure.operationKey: SocialWriteOperation.removeFriend.rawValue,
            SocialWriteFailure.messageKey: ""
        ]
        XCTAssertNil(SocialWriteFailure(userInfo: userInfo))
    }
}
