//
//  ColorHexParsingTests.swift
//  StreakSyncTests
//
//  Tests for the Color(hex:) and Color(lightHex:darkHex:) design-system parsers.
//

@testable import StreakSync
import SwiftUI
import UIKit
import XCTest

@MainActor
final class ColorHexParsingTests: XCTestCase {
    private let tolerance = 0.002

    // MARK: - Color(hex:)

    func testSixDigitHexMapsEachChannelToItsOwnByte() {
        // FF8000 is deliberately asymmetric: a shifted or swapped channel shows up.
        let probe = ColorProbe(Color(hex: "FF8000"))
        XCTAssertTrue(probe.didResolve)
        XCTAssertEqual(probe.red, 1.0, accuracy: tolerance)
        XCTAssertEqual(probe.green, 128.0 / 255.0, accuracy: tolerance)
        XCTAssertEqual(probe.blue, 0.0, accuracy: tolerance)
    }

    func testParsedHexColorsAreAlwaysOpaque() {
        for raw in ["FF8000", "#123456", "000000", "FFFFFF"] {
            let probe = ColorProbe(Color(hex: raw))
            XCTAssertEqual(probe.alpha, 1.0, accuracy: tolerance, "input: \(raw)")
        }
    }

    func testLeadingHashIsSkippedRatherThanParsedAsAHexDigit() {
        let withHash = ColorProbe(Color(hex: "#FF8000"))
        let withoutHash = ColorProbe(Color(hex: "FF8000"))
        XCTAssertEqual(withHash.channelDistance(to: withoutHash), 0.0, accuracy: tolerance)
        // Guard against both sides degrading to black together.
        XCTAssertGreaterThan(withHash.red, 0.5, "a '#' that is not skipped parses as black")
    }

    func testWhitespaceIsTrimmedBeforeTheHashIsDetected() {
        // Trimming only matters in combination with '#': Scanner already skips
        // leading whitespace, but hasPrefix("#") does not.
        let padded = ColorProbe(Color(hex: "  #FF8000\n"))
        XCTAssertEqual(padded.red, 1.0, accuracy: tolerance)
        XCTAssertEqual(padded.green, 128.0 / 255.0, accuracy: tolerance)
        XCTAssertEqual(padded.blue, 0.0, accuracy: tolerance)
    }

    func testDegenerateInputsResolveToOpaqueBlackWithoutTrapping() {
        for raw in ["", "#", "   ", "#####", "ZZZZZZ", "#GG0000"] {
            let probe = ColorProbe(Color(hex: raw))
            XCTAssertEqual(probe.red, 0.0, accuracy: tolerance, "input: '\(raw)'")
            XCTAssertEqual(probe.green, 0.0, accuracy: tolerance, "input: '\(raw)'")
            XCTAssertEqual(probe.blue, 0.0, accuracy: tolerance, "input: '\(raw)'")
            XCTAssertEqual(probe.alpha, 1.0, accuracy: tolerance, "input: '\(raw)'")
        }
    }

    // MARK: - Color(lightHex:darkHex:)

    func testAdaptiveColorResolvesLightHexInLightModeAndDarkHexInDarkMode() {
        let adaptive = Color(lightHex: "FF0000", darkHex: "0000FF")
        var light = ColorProbe(Color(hex: "000000"))
        var dark = ColorProbe(Color(hex: "000000"))
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            light = ColorProbe(adaptive)
        }
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            dark = ColorProbe(adaptive)
        }
        XCTAssertEqual(light.red, 1.0, accuracy: tolerance, "light mode should use lightHex")
        XCTAssertEqual(light.blue, 0.0, accuracy: tolerance, "light mode should use lightHex")
        XCTAssertEqual(dark.red, 0.0, accuracy: tolerance, "dark mode should use darkHex")
        XCTAssertEqual(dark.blue, 1.0, accuracy: tolerance, "dark mode should use darkHex")
    }
}
