//
//  FirebaseSocialService+DeferredWrites.swift
//  StreakSync
//
//  Fires interactive friend writes without awaiting the server ack, and reports rejections.
//

import FirebaseFirestore
import Foundation
import OSLog

// MARK: - Deferred Write Operations

/// The interactive friend writes that are fired without awaiting a server acknowledgement.
///
/// A Firestore write **never returns while the client is offline**: `FIRDocumentReference.h`
/// says the completion "will not be called when the device is offline, though local changes
/// will be visible immediately", and a Firestore write cannot be cancelled. Awaiting one
/// behind a spinner is therefore an unescapable hang, not a slow operation.
///
/// The mutation is applied to the local cache either way, and the friendship listeners in
/// `FirebaseSocialService+Leaderboard` re-read from that cache, so the UI confirms itself.
/// What we must not do is *drop* the completion handler — a rules rejection would then show
/// the user nothing at all, trading an indefinite spinner for a silent failure. Every case
/// here therefore carries the copy needed to tell the user which action undid itself.
enum SocialWriteOperation: String, Sendable {
    case sendFriendRequest
    case acceptFriendRequest
    case removeFriend
    case generateFriendCode

    /// Lead sentence of the alert. Past tense and operation-specific, because by the time a
    /// rejection lands the user has already seen the optimistic result on screen and needs
    /// to know which of several taps to redo.
    var failureHeadline: String {
        switch self {
        case .sendFriendRequest: return "Your friend request didn't go through."
        case .acceptFriendRequest: return "Couldn't accept that friend request."
        case .removeFriend: return "Couldn't remove that friend."
        case .generateFriendCode: return "Couldn't save your friend code."
        }
    }

    /// Sheet state that has to be undone *in addition to* re-reading friends and pending
    /// requests.
    ///
    /// Firestore has already reverted its own local mutation before it tells us:
    /// `SyncEngine::HandleRejectedWrite` runs `LocalStore::RejectBatch` (which drops the
    /// overlay) and only then `NotifyUser`. So a plain re-read is enough to put an
    /// optimistically removed row back. These are the pieces of UI state Firestore cannot
    /// know about.
    enum Rollback: Equatable {
        /// The re-read is the whole rollback.
        case reloadOnly
        /// Drop the green "Friend request sent to X!" line. Leaving it beside an error alert
        /// tells the user two opposite things at once.
        case clearSuccessMessage
        /// Forget the code the sheet optimistically displayed: the `friendCodes` mirror
        /// document was never written, so sharing that code hands out something nobody
        /// can redeem.
        case forgetFriendCode
    }

    var rollback: Rollback {
        switch self {
        case .sendFriendRequest: return .clearSuccessMessage
        case .acceptFriendRequest, .removeFriend: return .reloadOnly
        case .generateFriendCode: return .forgetFriendCode
        }
    }
}

// MARK: - Deferred Write Failure

/// A friend write that was applied to the local cache and then rejected by the server.
///
/// Travels from `FirebaseSocialService` to `FriendManagementView` as a `.socialWriteFailed`
/// notification, because the write outlives the `async` call that started it — the sheet is
/// no longer awaiting anything by the time the rejection arrives.
struct SocialWriteFailure: Equatable, Sendable {
    let operation: SocialWriteOperation
    let message: String

    /// `userInfo` keys. Internal rather than private so the round-trip test can assemble a
    /// deliberately malformed payload.
    static let operationKey = "socialWriteOperation"
    static let messageKey = "socialWriteFailureMessage"

    init(operation: SocialWriteOperation, error: Error) {
        self.operation = operation
        let reason = FirebaseSocialError.from(error).errorDescription?.nonEmpty
            ?? error.localizedDescription
        self.message = "\(operation.failureHeadline) \(reason)"
    }

    /// Decodes a `.socialWriteFailed` payload. Returns nil for anything malformed, including
    /// an empty message — `FriendManagementView` presents its alert on `errorMessage != nil`,
    /// so an empty string would put a blank alert on screen.
    init?(userInfo: [AnyHashable: Any]?) {
        guard let raw = userInfo?[Self.operationKey] as? String,
              let operation = SocialWriteOperation(rawValue: raw),
              let message = (userInfo?[Self.messageKey] as? String)?.nonEmpty else {
            return nil
        }
        self.operation = operation
        self.message = message
    }

    init?(notification: Notification) {
        self.init(userInfo: notification.userInfo)
    }

    var notificationUserInfo: [AnyHashable: Any] {
        [Self.operationKey: operation.rawValue, Self.messageKey: message]
    }

    func post(on center: NotificationCenter = .default) {
        center.post(name: .socialWriteFailed, object: nil, userInfo: notificationUserInfo)
    }
}

extension Notification.Name {
    /// Posted when a friend write that was fired without awaiting its acknowledgement is
    /// rejected by the server. Observed by `FriendManagementView`, which surfaces it through
    /// the same error alert every other failure in that sheet uses.
    static let socialWriteFailed = Notification.Name("SocialWriteFailed")
}

// MARK: - Firing Writes Without Awaiting the Ack

extension FirebaseSocialService {
    func fireSetData(_ data: [String: Any], on ref: DocumentReference, operation: SocialWriteOperation) {
        fireWrite(operation) { ref.setData(data, completion: $0) }
    }

    func fireUpdateData(_ fields: [AnyHashable: Any], on ref: DocumentReference, operation: SocialWriteOperation) {
        fireWrite(operation) { ref.updateData(fields, completion: $0) }
    }

    func fireDelete(_ ref: DocumentReference, operation: SocialWriteOperation) {
        fireWrite(operation) { ref.delete(completion: $0) }
    }

    func fireCommit(_ batch: WriteBatch, operation: SocialWriteOperation) {
        fireWrite(operation) { batch.commit(completion: $0) }
    }

    /// Starts `write` and returns immediately, keeping its completion handler.
    ///
    /// The completion only ever runs online, so its `nil` case is not "the write succeeded
    /// eventually" — it is "the server accepted it" — and its error case is always a real
    /// rejection (rules denial, failed precondition), never a network stall.
    private func fireWrite(
        _ operation: SocialWriteOperation,
        _ write: (@escaping @Sendable (Error?) -> Void) -> Void
    ) {
        // Hoisted out of the closure: `logger` is MainActor-isolated, the completion is not.
        // Same pattern as the snapshot listeners in FirebaseSocialService+Leaderboard.
        let log = logger
        write { [weak self] error in
            guard let error else { return }
            let failure = SocialWriteFailure(operation: operation, error: error)
            log.error("Deferred \(operation.rawValue) write rejected: \(error.localizedDescription)")
            Task { @MainActor in
                self?.reportDeferredWriteFailure(failure)
            }
        }
    }

    /// Expected flow once the server has rejected a fired-but-not-awaited friend write:
    ///   1. Firestore already dropped the local overlay (`LocalStore::RejectBatch`) before
    ///      calling us, so its cache is back to the server's truth.
    ///   2. Drop our own 60 s friends cache. Without this, `listFriends()` would re-serve the
    ///      optimistic list to step 4 and the reverted row would stay hidden for up to a
    ///      minute. Mirrors what the friendship listeners do on every snapshot.
    ///   3. Post `.socialWriteFailed` carrying the operation and a user-facing message.
    ///   4. `FriendManagementView.handleDeferredWriteFailure` shows that message in its
    ///      existing error alert, applies `operation.rollback`, and re-reads friends and
    ///      pending requests — that re-read is what restores the row.
    private func reportDeferredWriteFailure(_ failure: SocialWriteFailure) {
        cachedFriends = nil
        friendsCacheTimestamp = nil
        failure.post()
    }
}
