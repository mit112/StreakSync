//
//  SyncFailureClassifierTests.swift
//  StreakSyncTests
//
//  Pins network outages to .offline and everything else to .failed.
//

import FirebaseFirestore
@testable import StreakSync
import XCTest

final class SyncFailureClassifierTests: XCTestCase {

    private func firestoreError(_ code: FirestoreErrorCode.Code) -> NSError {
        NSError(domain: FirestoreErrorDomain, code: code.rawValue)
    }

    /// The whole point: an outage must reach the honest "offline" state rather than a
    /// red "Sync failed". Before this mapping existed, `.offline` was only ever set for
    /// "no authenticated user", so a real outage could never produce it.
    func testUnavailableIsClassifiedAsOffline() {
        XCTAssertEqual(
            SyncFailureClassifier.state(for: firestoreError(.unavailable)),
            .offline
        )
    }

    /// The risk of the mapping is over-reach: a real bug hiding behind "you're offline".
    /// A permission failure is a bug, not a network blip.
    func testPermissionDeniedStaysAFailure() {
        XCTAssertEqual(
            SyncFailureClassifier.state(for: firestoreError(.permissionDenied)),
            .failed(firestoreError(.permissionDenied))
        )
    }

    func testUnauthenticatedStaysAFailure() {
        XCTAssertEqual(
            SyncFailureClassifier.state(for: firestoreError(.unauthenticated)),
            .failed(firestoreError(.unauthenticated))
        )
    }

    /// Code 14 in some other domain is not a Firestore outage. Matching on the code
    /// alone would classify unrelated errors as offline.
    func testMatchingCodeInAnotherDomainStaysAFailure() {
        let imposter = NSError(
            domain: "com.streaksync.something.else",
            code: FirestoreErrorCode.unavailable.rawValue
        )
        XCTAssertEqual(SyncFailureClassifier.state(for: imposter), .failed(imposter))
    }

    func testNonFirestoreErrorStaysAFailure() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        XCTAssertEqual(SyncFailureClassifier.state(for: error), .failed(error))
    }
}
