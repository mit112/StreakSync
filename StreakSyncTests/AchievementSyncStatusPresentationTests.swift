//
//  AchievementSyncStatusPresentationTests.swift
//  StreakSyncTests
//
//  The copy a user reads when their achievement backup is broken
//

@testable import StreakSync
import XCTest

@MainActor
final class AchievementSyncStatusPresentationTests: XCTestCase {
    // MARK: - Healthy States

    func testSyncDisabledOutranksAStaleFailure() {
        // syncIfEnabled returns early when the switch is off without clearing `status`,
        // so the last failure would otherwise keep accusing a feature that is off.
        let presentation = AchievementSyncStatusPresentation.resolve(
            status: .error(.payloadTooLarge(kilobytes: 812)),
            isSyncEnabled: false
        )
        XCTAssertEqual(presentation.title, "Backup is off")
        XCTAssertEqual(presentation.severity, .neutral)
    }

    func testIdleSaysTheBackupHasNotRunYet() throws {
        let presentation = AchievementSyncStatusPresentation.resolve(status: .idle, isSyncEnabled: true)
        XCTAssertEqual(presentation.title, "Not backed up yet")
        XCTAssertEqual(presentation.severity, .neutral)
        let detail = try XCTUnwrap(presentation.detail)
        XCTAssertTrue(detail.contains("Sync Now"))
    }

    func testSyncingReportsProgressWithoutADetailLine() {
        let presentation = AchievementSyncStatusPresentation.resolve(status: .syncing, isSyncEnabled: true)
        XCTAssertEqual(presentation.severity, .inProgress)
        XCTAssertNil(presentation.detail)
        XCTAssertNil(presentation.relativeDate)
    }

    func testSuccessCarriesTheDateAndLeavesFormattingToTheView() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let presentation = AchievementSyncStatusPresentation.resolve(status: .success(date), isSyncEnabled: true)
        XCTAssertEqual(presentation.title, "Backed up")
        XCTAssertEqual(presentation.severity, .ok)
        XCTAssertEqual(presentation.relativeDate, date)
        XCTAssertNil(presentation.detail)
    }

    // MARK: - Failures

    func testPayloadTooLargeNamesTheSizeTheLimitAndTheRemedy() throws {
        let detail = try Self.detail(for: .payloadTooLarge(kilobytes: 812))
        XCTAssertTrue(detail.contains("812 KB"), detail)
        XCTAssertTrue(detail.contains("700 KB"), detail)
        XCTAssertTrue(detail.contains("Export Data"), detail)
    }

    func testPayloadTooLargeSaysRetryingWillNotHelp() throws {
        // The 700KB guard is deterministic: "Sync Now" is a lie until the data shrinks,
        // so the copy has to say so rather than leaving the user tapping it.
        let detail = try Self.detail(for: .payloadTooLarge(kilobytes: 812))
        XCTAssertTrue(detail.contains("Syncing again won't help"), detail)
    }

    func testPayloadTooLargeSaysTheDataIsNotLost() throws {
        let detail = try Self.detail(for: .payloadTooLarge(kilobytes: 812))
        XCTAssertTrue(detail.contains("safe on this device"), detail)
    }

    func testNetworkUnavailablePromisesAnAutomaticRetry() throws {
        let detail = try Self.detail(for: .networkUnavailable)
        XCTAssertTrue(detail.contains("once you're online"), detail)
    }

    func testSignedOutPromisesNothingWasLostAndNamesTheFix() throws {
        let presentation = Self.presentation(for: .notSignedIn)
        XCTAssertEqual(presentation.title, "Not backed up — you're signed out")
        let detail = try XCTUnwrap(presentation.detail)
        XCTAssertTrue(detail.contains("Nothing on this device was lost"), detail)
        XCTAssertTrue(detail.contains("Sign in again"), detail)
    }

    func testPermissionDeniedPointsAtAccountAndSupport() throws {
        let detail = try Self.detail(for: .permissionDenied)
        XCTAssertTrue(detail.contains("Account"), detail)
        XCTAssertTrue(detail.contains("contact support"), detail)
    }

    func testUnknownFailureQuotesTheUnderlyingMessage() throws {
        let detail = try Self.detail(for: .unknown("Missing or insufficient permissions."))
        XCTAssertTrue(detail.contains("Missing or insufficient permissions."), detail)
    }

    // MARK: - Invariants

    func testEveryFailureCarriesASymbolATitleAndADetail() throws {
        // Colour is never the only signal: severity tints the glyph, but the glyph name
        // and the text stand on their own (WCAG 2.2 AA, 1.4.1).
        for failure in Self.allFailures {
            let presentation = Self.presentation(for: failure)
            XCTAssertFalse(presentation.symbolName.isEmpty, "\(failure) has no symbol")
            XCTAssertFalse(presentation.title.isEmpty, "\(failure) has no title")
            let detail = try XCTUnwrap(presentation.detail, "\(failure) has no detail")
            XCTAssertFalse(detail.isEmpty, "\(failure) has an empty detail")
        }
    }

    func testTransientFailuresAreNotFlaggedAsTheUsersProblem() {
        for failure in [AchievementSyncFailure.networkUnavailable, .serviceBusy] {
            let presentation = Self.presentation(for: failure)
            XCTAssertEqual(presentation.severity, .neutral, "\(failure) should not raise a warning")
        }
    }

    func testFailuresNeedingADecisionAreFlaggedAsWarnings() {
        let actionable: [AchievementSyncFailure] = [
            .notSignedIn,
            .permissionDenied,
            .payloadTooLarge(kilobytes: 812),
            .unknown("boom")
        ]
        for failure in actionable {
            let presentation = Self.presentation(for: failure)
            XCTAssertEqual(presentation.severity, .warning, "\(failure) needs a warning")
        }
    }

    // MARK: - VoiceOver

    func testAccessibilityLabelSpeaksTitleThenDateThenDetail() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let presentation = AchievementSyncStatusPresentation.resolve(status: .success(date), isSyncEnabled: true)
        XCTAssertEqual(
            presentation.accessibilityLabel(relativeDescription: "5 minutes ago"),
            "Achievement backup. Backed up. 5 minutes ago"
        )
    }

    func testAccessibilityLabelCarriesTheWholeFailureNotJustTheTitle() {
        let presentation = Self.presentation(for: .payloadTooLarge(kilobytes: 812))
        let label = presentation.accessibilityLabel(relativeDescription: nil)
        XCTAssertTrue(label.hasPrefix("Achievement backup. Achievements are too large to back up."), label)
        XCTAssertTrue(label.contains("812 KB"), label)
    }

    // MARK: - Helpers

    private static let allFailures: [AchievementSyncFailure] = [
        .notSignedIn,
        .networkUnavailable,
        .permissionDenied,
        .serviceBusy,
        .payloadTooLarge(kilobytes: 812),
        .unknown("boom")
    ]

    private static func presentation(for failure: AchievementSyncFailure) -> AchievementSyncStatusPresentation {
        AchievementSyncStatusPresentation.resolve(status: .error(failure), isSyncEnabled: true)
    }

    private static func detail(for failure: AchievementSyncFailure) throws -> String {
        try XCTUnwrap(presentation(for: failure).detail)
    }
}
