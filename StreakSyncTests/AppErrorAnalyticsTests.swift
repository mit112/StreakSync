//
//  AppErrorAnalyticsTests.swift
//  StreakSyncTests
//
//  Tests for AppError severity classification and the analytics payload contract.
//

@testable import StreakSync
import XCTest

final class AppErrorAnalyticsTests: XCTestCase {
    // MARK: - Severity classification

    func testCriticalSeveritiesAreTheTwoUnrecoverableFailures() {
        XCTAssertEqual(AppError.shareExtension(.appGroupAccessFailed).severity, .critical)
        XCTAssertEqual(AppError.persistence(.storageFull).severity, .critical)
    }

    func testHighSeveritiesEscalateToAnAlert() {
        XCTAssertEqual(AppError.shareExtension(.saveFailed(underlying: nil)).severity, .high)
        XCTAssertEqual(AppError.shareExtension(.notificationFailed).severity, .high)
        XCTAssertEqual(AppError.persistence(.dataCorrupted(dataType: "results")).severity, .high)
        XCTAssertEqual(AppError.persistence(.migrationFailed(from: "1", to: "2")).severity, .high)
        XCTAssertEqual(AppError.sync(.appGroupCommunicationFailed).severity, .high)
        XCTAssertEqual(AppError.ui(.stateInconsistency(description: "x")).severity, .high)
    }

    func testDuplicateResultIsTheOnlyLowSeverityError() {
        XCTAssertEqual(AppError.sync(.resultAlreadyProcessed).severity, .low)
        let lowSeverityCount = AppErrorFixtures.all.filter { $0.severity == .low }.count
        XCTAssertEqual(lowSeverityCount, 1)
    }

    func testEveryParsingErrorStaysMediumBecauseParsingIsRecoverable() {
        for error in AppErrorFixtures.parsing {
            XCTAssertEqual(AppError.parsing(error).severity, .medium, "\(error)")
        }
    }

    func testPersistenceFallsThroughToMediumForOrdinaryFailures() {
        let saveFailed = AppError.persistence(.saveFailed(dataType: "x", underlying: nil))
        XCTAssertEqual(saveFailed.severity, .medium)
        XCTAssertEqual(AppError.persistence(.keyNotFound(key: "x")).severity, .medium)
        let encodingFailed = AppError.persistence(.encodingFailed(underlying: AppErrorFixtures.underlying))
        XCTAssertEqual(encodingFailed.severity, .medium)
    }

    func testSyncFallsThroughToMediumForOrdinaryFailures() {
        XCTAssertEqual(AppError.sync(.syncTimeout).severity, .medium)
        XCTAssertEqual(AppError.sync(.darwinNotificationFailed).severity, .medium)
        XCTAssertEqual(AppError.sync(.notificationPostFailed).severity, .medium)
    }

    func testUIFallsThroughToMediumForOrdinaryFailures() {
        XCTAssertEqual(AppError.ui(.navigationFailed(destination: "x")).severity, .medium)
        XCTAssertEqual(AppError.ui(.viewModelNotInitialized).severity, .medium)
    }

    // MARK: - Error codes

    func testErrorCodesAreUniqueAcrossEveryCase() {
        let codes = AppErrorFixtures.all.map(\.errorCode)
        XCTAssertEqual(Set(codes).count, codes.count, "duplicate error codes: \(codes)")
    }

    func testErrorCodePrefixMatchesTheCategory() throws {
        let prefixes = [
            "share_extension": "SE",
            "parsing": "PA",
            "persistence": "PE",
            "sync": "SY",
            "ui": "UI"
        ]
        for error in AppErrorFixtures.all {
            let expected = try XCTUnwrap(prefixes[error.errorCategory], "unmapped \(error.errorCategory)")
            XCTAssertTrue(error.errorCode.hasPrefix(expected), "\(error.errorCode) vs \(error.errorCategory)")
        }
    }

    func testEveryCategoryOwnsItsOwnHundredBlock() throws {
        let blocks = [
            "share_extension": 1,
            "parsing": 2,
            "persistence": 3,
            "sync": 4,
            "ui": 5
        ]
        for error in AppErrorFixtures.all {
            let expected = try XCTUnwrap(blocks[error.errorCategory])
            let numeric = try XCTUnwrap(Int(error.errorCode.dropFirst(2)), "bad code \(error.errorCode)")
            XCTAssertEqual(numeric / 100, expected, "\(error.errorCode) is outside its block")
        }
    }

    /// These strings are the join key for anything reading crash/analytics
    /// dashboards. Renumbering silently orphans historical data.
    func testKnownErrorCodesAreStable() {
        XCTAssertEqual(AppError.shareExtension(.noContent).errorCode, "SE100")
        XCTAssertEqual(AppError.parsing(.unknownGameFormat(text: "x")).errorCode, "PA200")
        XCTAssertEqual(AppError.persistence(.storageFull).errorCode, "PE304")
        XCTAssertEqual(AppError.sync(.resultAlreadyProcessed).errorCode, "SY404")
        XCTAssertEqual(AppError.ui(.viewModelNotInitialized).errorCode, "UI504")
    }

    // MARK: - Analytics payload

    func testAnalyticsPayloadAlwaysCarriesCategoryCodeAndSeverity() throws {
        let severities = ["low", "medium", "high", "critical"]
        for error in AppErrorFixtures.all {
            let properties = error.analyticsProperties
            XCTAssertEqual(properties["error_category"] as? String, error.errorCategory)
            XCTAssertEqual(properties["error_code"] as? String, error.errorCode)
            let severity = try XCTUnwrap(properties["severity"] as? String, "no severity for \(error)")
            XCTAssertTrue(severities.contains(severity), "unknown severity \(severity)")
        }
    }

    func testSeverityIsSerialisedWithItsAnalyticsName() throws {
        let critical = AppError.persistence(.storageFull).analyticsProperties
        let low = AppError.sync(.resultAlreadyProcessed).analyticsProperties
        let high = AppError.sync(.appGroupCommunicationFailed).analyticsProperties
        let medium = AppError.parsing(.dateParsingFailed).analyticsProperties
        let criticalName = try XCTUnwrap(critical["severity"] as? String)
        let lowName = try XCTUnwrap(low["severity"] as? String)
        let highName = try XCTUnwrap(high["severity"] as? String)
        let mediumName = try XCTUnwrap(medium["severity"] as? String)
        XCTAssertEqual(criticalName, "critical")
        XCTAssertEqual(lowName, "low")
        XCTAssertEqual(highName, "high")
        XCTAssertEqual(mediumName, "medium")
    }

    func testAnalyticsPayloadUsesACategorySpecificTypeKey() throws {
        let expectedKeys = [
            "share_extension": "share_error_type",
            "parsing": "parsing_error_type",
            "persistence": "persistence_error_type",
            "sync": "sync_error_type",
            "ui": "ui_error_type"
        ]
        for error in AppErrorFixtures.all {
            let key = try XCTUnwrap(expectedKeys[error.errorCategory])
            let properties = error.analyticsProperties
            let identifier = try XCTUnwrap(properties[key] as? String, "no \(key) for \(error)")
            XCTAssertFalse(identifier.isEmpty)
            XCTAssertEqual(properties.count, 4, "unexpected payload shape for \(error)")
        }
    }

    func testAnalyticsIdentifiersAreUniqueWithinEachCategory() throws {
        let groups = [
            ("share_error_type", AppErrorFixtures.shareExtension.map(AppError.shareExtension)),
            ("parsing_error_type", AppErrorFixtures.parsing.map(AppError.parsing)),
            ("persistence_error_type", AppErrorFixtures.persistence.map(AppError.persistence)),
            ("sync_error_type", AppErrorFixtures.sync.map(AppError.sync)),
            ("ui_error_type", AppErrorFixtures.ui.map(AppError.ui))
        ]
        for (key, errors) in groups {
            var identifiers: [String] = []
            for error in errors {
                let identifier = try XCTUnwrap(error.analyticsProperties[key] as? String)
                identifiers.append(identifier)
            }
            XCTAssertEqual(Set(identifiers).count, errors.count, "duplicate \(key): \(identifiers)")
        }
    }

    /// The payload is documented as "safe for analytics (no user data)". Every
    /// case that carries a user-supplied string is checked here.
    func testAnalyticsPayloadNeverCarriesUserSuppliedText() {
        let secret = "SENTINEL-DO-NOT-SHIP"
        let errors: [AppError] = [
            .shareExtension(.invalidContentType(secret)),
            .parsing(.unknownGameFormat(text: secret)),
            .parsing(.invalidScoreFormat(game: secret, score: secret)),
            .parsing(.malformedGameData(game: secret, reason: secret)),
            .parsing(.unsupportedGame(detectedName: secret)),
            .persistence(.dataCorrupted(dataType: secret)),
            .persistence(.keyNotFound(key: secret)),
            .persistence(.migrationFailed(from: secret, to: secret)),
            .sync(.urlSchemeInvalid(url: secret)),
            .ui(.navigationFailed(destination: secret)),
            .ui(.missingRequiredData(viewName: secret)),
            .ui(.stateInconsistency(description: secret))
        ]
        for error in errors {
            let flattened = error.analyticsProperties.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            XCTAssertFalse(flattened.contains(secret), "leaked user text for \(error): \(flattened)")
        }
    }
}
