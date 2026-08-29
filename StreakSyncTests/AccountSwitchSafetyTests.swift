//
//  AccountSwitchSafetyTests.swift
//  StreakSyncTests
//
//  The empty-account-switch decision and the non-destructive local archive
//

@testable import StreakSync
import XCTest

final class AccountSwitchSafetyTests: XCTestCase {
    private let apple = ["apple.com"]
    private let google = ["google.com"]

    // MARK: - shouldWarnAboutEmptyAccountSwitch

    /// The case the whole thing exists for: an Apple user signs in with Google, a
    /// provider they've never used, and Firebase silently mints an empty account.
    func testWarnsWhenAnAppleUserLandsOnAnEmptyGoogleAccount() {
        XCTAssertTrue(
            AppContainer.shouldWarnAboutEmptyAccountSwitch(
                previousWasAnonymous: false,
                previousResultCount: 42,
                newResultCountAfterSync: 0,
                previousProviderIDs: apple,
                newProviderIDs: google
            )
        )
    }

    /// A real account switch to an account that has history is not a mistake.
    func testDoesNotWarnWhenTheNewAccountHasData() {
        XCTAssertFalse(
            AppContainer.shouldWarnAboutEmptyAccountSwitch(
                previousWasAnonymous: false,
                previousResultCount: 42,
                newResultCountAfterSync: 17,
                previousProviderIDs: apple,
                newProviderIDs: google
            )
        )
    }

    /// A brand-new user signing up from a guest session has nothing to lose and must
    /// not be nagged — this is the ordinary happy path.
    func testDoesNotWarnWhenThePreviousSessionWasAnonymous() {
        XCTAssertFalse(
            AppContainer.shouldWarnAboutEmptyAccountSwitch(
                previousWasAnonymous: true,
                previousResultCount: 0,
                newResultCountAfterSync: 0,
                previousProviderIDs: [],
                newProviderIDs: google
            )
        )
    }

    /// Signing in the same way as last time is never the mistake this detects, even
    /// when the sync came back empty (offline, or a genuinely empty account).
    func testDoesNotWarnWhenTheProviderIsUnchanged() {
        XCTAssertFalse(
            AppContainer.shouldWarnAboutEmptyAccountSwitch(
                previousWasAnonymous: false,
                previousResultCount: 42,
                newResultCountAfterSync: 0,
                previousProviderIDs: apple,
                newProviderIDs: apple
            )
        )
    }

    /// A multi-provider account that overlaps on one provider is the same person.
    func testDoesNotWarnWhenProviderSetsOverlap() {
        XCTAssertFalse(
            AppContainer.shouldWarnAboutEmptyAccountSwitch(
                previousWasAnonymous: false,
                previousResultCount: 42,
                newResultCountAfterSync: 0,
                previousProviderIDs: apple + google,
                newProviderIDs: google
            )
        )
    }

    /// Nothing was lost, so there is nothing to tell them about.
    func testDoesNotWarnWhenThePreviousSessionHadNoResults() {
        XCTAssertFalse(
            AppContainer.shouldWarnAboutEmptyAccountSwitch(
                previousWasAnonymous: false,
                previousResultCount: 0,
                newResultCountAfterSync: 0,
                previousProviderIDs: apple,
                newProviderIDs: google
            )
        )
    }

    /// Signing out drops to anonymous, which has no provider IDs. That is not a switch
    /// to a new account and must not warn.
    func testDoesNotWarnWhenTheNewSessionIsAnonymous() {
        XCTAssertFalse(
            AppContainer.shouldWarnAboutEmptyAccountSwitch(
                previousWasAnonymous: false,
                previousResultCount: 42,
                newResultCountAfterSync: 0,
                previousProviderIDs: apple,
                newProviderIDs: []
            )
        )
    }

    // MARK: - Archive round trip

    /// An account switch must be recoverable. This is the property that makes every
    /// misclassification survivable, including the ones no detector catches.
    func testArchiveHidesDataFromTheLiveStoreAndRestorePutsItBack() throws {
        let suiteName = "AccountSwitchSafetyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = UserDefaultsPersistenceService(userDefaults: defaults)
        let key = UserDefaultsPersistenceService.Keys.streaks
        try service.save(["alpha", "beta"], forKey: key)
        XCTAssertEqual(service.load([String].self, forKey: key), ["alpha", "beta"])

        service.archiveAll(namespace: "uid-A")
        defer { service.restoreArchive(namespace: "uid-A") }

        XCTAssertNil(service.load([String].self, forKey: key), "the live store is empty after a switch")
        XCTAssertTrue(service.hasArchive(namespace: "uid-A"))
        XCTAssertFalse(service.hasArchive(namespace: "uid-B"), "another account has no archive")

        XCTAssertTrue(service.restoreArchive(namespace: "uid-A"))
        XCTAssertEqual(
            service.load([String].self, forKey: key), ["alpha", "beta"],
            "signing back in must return the data verbatim"
        )
        XCTAssertFalse(service.hasArchive(namespace: "uid-A"), "a restored archive is consumed")
    }

    /// Restoring an account this device has never archived must be a no-op rather than
    /// wiping whatever is currently live.
    func testRestoringAnUnknownNamespaceLeavesLiveDataAlone() throws {
        let suiteName = "AccountSwitchSafetyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = UserDefaultsPersistenceService(userDefaults: defaults)
        let key = UserDefaultsPersistenceService.Keys.streaks
        try service.save(["kept"], forKey: key)

        XCTAssertFalse(service.restoreArchive(namespace: "never-seen"))
        XCTAssertEqual(service.load([String].self, forKey: key), ["kept"])
    }
}
