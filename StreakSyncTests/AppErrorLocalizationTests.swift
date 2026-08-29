//
//  AppErrorLocalizationTests.swift
//  StreakSyncTests
//
//  Tests for AppError's LocalizedError surface: description, reason and recovery routing.
//

@testable import StreakSync
import XCTest

final class AppErrorLocalizationTests: XCTestCase {
    // MARK: - Every case is presentable

    func testEveryErrorCaseHasANonEmptyDescription() throws {
        for error in AppErrorFixtures.all {
            let description = try XCTUnwrap(error.errorDescription, "no errorDescription for \(error)")
            XCTAssertFalse(description.isEmpty, "empty errorDescription for \(error)")
        }
    }

    func testEveryErrorCaseHasANonEmptyFailureReason() throws {
        for error in AppErrorFixtures.all {
            let reason = try XCTUnwrap(error.failureReason, "no failureReason for \(error)")
            XCTAssertFalse(reason.isEmpty, "empty failureReason for \(error)")
        }
    }

    /// `.sync(.resultAlreadyProcessed)` is the single case that deliberately
    /// offers no recovery step — there is nothing for the user to do about a
    /// duplicate. Every other case must tell the user what to try next.
    func testDuplicateResultIsTheOnlyCaseWithoutARecoverySuggestion() throws {
        for error in AppErrorFixtures.all {
            if case .sync(.resultAlreadyProcessed) = error {
                XCTAssertNil(error.recoverySuggestion)
                continue
            }
            let suggestion = try XCTUnwrap(error.recoverySuggestion, "no recovery for \(error)")
            XCTAssertFalse(suggestion.isEmpty, "empty recovery for \(error)")
        }
    }

    // MARK: - Descriptions must not be copy-pasted between sibling cases

    func testShareExtensionDescriptionsAreDistinct() {
        assertDistinctDescriptions(AppErrorFixtures.shareExtension.map(AppError.shareExtension))
    }

    func testParsingDescriptionsAreDistinct() {
        assertDistinctDescriptions(AppErrorFixtures.parsing.map(AppError.parsing))
    }

    func testPersistenceDescriptionsAreDistinct() {
        assertDistinctDescriptions(AppErrorFixtures.persistence.map(AppError.persistence))
    }

    func testSyncDescriptionsAreDistinct() {
        assertDistinctDescriptions(AppErrorFixtures.sync.map(AppError.sync))
    }

    func testUIDescriptionsAreDistinct() {
        assertDistinctDescriptions(AppErrorFixtures.ui.map(AppError.ui))
    }

    // MARK: - Underlying errors are surfaced, not swallowed

    func testPersistenceSaveFailedPrefersTheUnderlyingErrorAsItsReason() {
        let error = AppError.persistence(
            .saveFailed(dataType: "GameResult", underlying: AppErrorFixtures.underlying)
        )
        XCTAssertEqual(error.failureReason, "the disk gave up")
    }

    func testPersistenceSaveFailedFallsBackToAGenericReasonWithoutAnUnderlyingError() {
        let withUnderlying = AppError.persistence(
            .saveFailed(dataType: "GameResult", underlying: AppErrorFixtures.underlying)
        )
        let withoutUnderlying = AppError.persistence(
            .saveFailed(dataType: "GameResult", underlying: nil)
        )
        XCTAssertNotEqual(withUnderlying.failureReason, withoutUnderlying.failureReason)
        XCTAssertNotNil(withoutUnderlying.failureReason)
    }

    func testPersistenceLoadFailedPrefersTheUnderlyingErrorAsItsReason() {
        let error = AppError.persistence(
            .loadFailed(dataType: "GameResult", underlying: AppErrorFixtures.underlying)
        )
        XCTAssertEqual(error.failureReason, "the disk gave up")
    }

    func testEncodingFailureReasonIsTheUnderlyingErrorDescription() {
        let error = AppError.persistence(.encodingFailed(underlying: AppErrorFixtures.underlying))
        XCTAssertEqual(error.failureReason, "the disk gave up")
    }

    func testShareExtensionSaveFailedSurfacesTheUnderlyingError() {
        let error = AppError.shareExtension(.saveFailed(underlying: AppErrorFixtures.underlying))
        XCTAssertEqual(error.failureReason, "the disk gave up")
    }

    func testMalformedGameDataReasonIsThePassedThroughParserReason() {
        let error = AppError.parsing(.malformedGameData(game: "Wordle", reason: "row 3 has 6 tiles"))
        XCTAssertEqual(error.failureReason, "row 3 has 6 tiles")
    }

    func testStateInconsistencyReasonIsThePassedThroughDescription() {
        let error = AppError.ui(.stateInconsistency(description: "streak 5 with 0 results"))
        XCTAssertEqual(error.failureReason, "streak 5 with 0 results")
    }

    // MARK: - helpAnchor routing

    func testHelpAnchorMatchesTheErrorCategory() {
        XCTAssertEqual(AppError.shareExtension(.noContent).helpAnchor, "share-extension-errors")
        XCTAssertEqual(AppError.parsing(.dateParsingFailed).helpAnchor, "game-parsing-errors")
        XCTAssertEqual(AppError.persistence(.storageFull).helpAnchor, "data-storage-errors")
        XCTAssertEqual(AppError.sync(.syncTimeout).helpAnchor, "sync-errors")
        XCTAssertEqual(AppError.ui(.sheetPresentationFailed).helpAnchor, "interface-errors")
    }

    // MARK: - Format-string hygiene

    /// Every localized value is fed through `String(format:)` with arguments the
    /// current strings table does not declare. If someone adds a `%@` to the
    /// table for a case that passes no argument, the raw specifier ships to users.
    func testNoUserFacingStringLeaksAnUnsubstitutedFormatSpecifier() {
        for error in AppErrorFixtures.all {
            assertNoFormatSpecifier(error.errorDescription, in: error)
            assertNoFormatSpecifier(error.failureReason, in: error)
            assertNoFormatSpecifier(error.recoverySuggestion, in: error)
        }
    }

    // MARK: - Helpers

    private func assertNoFormatSpecifier(
        _ value: String?,
        in error: AppError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let value else { return }
        XCTAssertFalse(value.contains("%@"), "specifier in \(error): \(value)", file: file, line: line)
        XCTAssertFalse(value.contains("%d"), "specifier in \(error): \(value)", file: file, line: line)
    }

    private func assertDistinctDescriptions(
        _ errors: [AppError],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let descriptions = errors.compactMap(\.errorDescription)
        XCTAssertEqual(descriptions.count, errors.count, "a case returned nil", file: file, line: line)
        XCTAssertEqual(
            Set(descriptions).count,
            errors.count,
            "two sibling cases share a string: \(descriptions)",
            file: file,
            line: line
        )
    }
}
