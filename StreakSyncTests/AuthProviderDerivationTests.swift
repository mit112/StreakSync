//
//  AuthProviderDerivationTests.swift
//  StreakSyncTests
//
//  Tests for AppContainer.deriveProvider(fromProviderIDs:) and
//  the ensureProfile() provider detection in FirebaseSocialService.
//

@testable import StreakSync
import XCTest

final class AuthProviderDerivationTests: XCTestCase {
    // MARK: - AppContainer.deriveProvider(fromProviderIDs:)

    func testDeriveProvider_emptyIDs_returnsAnonymous() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: []), .anonymous)
    }

    func testDeriveProvider_appleID_returnsApple() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["apple.com"]), .apple)
    }

    func testDeriveProvider_googleID_returnsGoogle() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["google.com"]), .google)
    }

    func testDeriveProvider_appleBeatsGoogle_whenBoth() {
        // apple.com takes priority (matches first in the if-chain)
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["apple.com", "google.com"]), .apple)
    }

    func testDeriveProvider_unknownID_returnsAnonymous() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["password"]), .anonymous)
    }

    // MARK: - AuthProvider raw values used in Firestore (must not change)

    func testAuthProviderRawValues() {
        XCTAssertEqual(AuthProvider.anonymous.rawValue, "anonymous")
        XCTAssertEqual(AuthProvider.apple.rawValue, "apple")
        XCTAssertEqual(AuthProvider.google.rawValue, "google")
    }

    func testDeriveProvider_rawValue_forApple() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["apple.com"]).rawValue, "apple")
    }

    func testDeriveProvider_rawValue_forGoogle() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["google.com"]).rawValue, "google")
    }

    func testDeriveProvider_rawValue_forAnonymous() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: []).rawValue, "anonymous")
    }
}
