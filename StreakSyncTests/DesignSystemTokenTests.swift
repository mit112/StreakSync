//
//  DesignSystemTokenTests.swift
//  StreakSyncTests
//
//  Contrast, palette and type-ramp invariants for the Design System tokens.
//

@testable import StreakSync
import SwiftUI
import XCTest

@MainActor
final class DesignSystemTokenTests: XCTestCase {
    private let tolerance = 0.002
    private var white: ColorProbe { ColorProbe(Color(hex: "FFFFFF")) }
    private var black: ColorProbe { ColorProbe(Color(hex: "000000")) }

    // MARK: - Brand contrast (WCAG 2.2 SC 1.4.11 non-text contrast is 3:1)

    func testBrandPrimaryClearsNonTextContrastOnWhite() {
        // #168BFA measures ~3.44:1 against white.
        let ratio = ColorProbe(StreakSyncBrand.primary).contrastRatio(against: white)
        XCTAssertGreaterThanOrEqual(ratio, 3.0, "brand blue no longer clears 3:1 on a light surface")
    }

    func testBrandSuccessClearsNonTextContrastOnWhite() {
        // #0CA678 measures ~3.12:1 — the tightest margin in the brand palette.
        let ratio = ColorProbe(StreakSyncBrand.success).contrastRatio(against: white)
        XCTAssertGreaterThanOrEqual(ratio, 3.0, "success green no longer clears 3:1 on a light surface")
    }

    func testBrandStreakIsReadableOnDarkSurfaces() {
        // #FF9F0A measures ~10.2:1 against black. See NOTES.md — it does not
        // clear 3:1 against white, so this pins the surface it is safe on.
        let ratio = ColorProbe(StreakSyncBrand.streak).contrastRatio(against: black)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "streak orange is no longer readable on a dark surface")
    }

    func testBrandStreakIsNotTheSameHueAsBrandPrimary() {
        let distance = ColorProbe(StreakSyncBrand.streak).channelDistance(to: ColorProbe(StreakSyncBrand.primary))
        XCTAssertGreaterThan(distance, 0.5, "the streak accent collapsed into the primary brand color")
    }

    // MARK: - PaletteColor

    func testEveryPaletteRawValueIsASixDigitHexString() {
        for palette in PaletteColor.allCases {
            XCTAssertEqual(palette.rawValue.count, 6, "\(palette) hex is not six digits")
            XCTAssertTrue(palette.rawValue.allSatisfy(\.isHexDigit), "\(palette) has a non-hex digit")
        }
    }

    func testPaletteColorIsBuiltFromItsOwnRawHex() {
        let probe = ColorProbe(PaletteColor.primary.color)
        XCTAssertEqual(probe.red, Double(0x58) / 255.0, accuracy: tolerance)
        XCTAssertEqual(probe.green, Double(0xCC) / 255.0, accuracy: tolerance)
        XCTAssertEqual(probe.blue, Double(0x02) / 255.0, accuracy: tolerance)
    }

    /// Every decorative token needs a dark-mode counterpart. The one deliberate
    /// exception is secondary text, which is the same grey in both modes.
    func testEveryPaletteEntryHasADistinctDarkVariantExceptSecondaryText() {
        for palette in PaletteColor.allCases {
            let distance = ColorProbe(palette.color).channelDistance(to: ColorProbe(palette.darkVariant))
            if palette == .textSecondary {
                XCTAssertEqual(distance, 0.0, accuracy: tolerance, "textSecondary should not change")
            } else {
                XCTAssertGreaterThan(distance, 0.01, "\(palette) has no distinct dark-mode variant")
            }
        }
    }

    func testPaletteBackgroundInvertsBetweenLightAndDark() {
        let light = ColorProbe(PaletteColor.background.color).relativeLuminance
        let dark = ColorProbe(PaletteColor.background.darkVariant).relativeLuminance
        XCTAssertGreaterThan(light, 0.9, "the light background is no longer near-white")
        XCTAssertLessThan(dark, 0.05, "the dark background is no longer near-black")
    }

    func testPaletteTextPrimaryInvertsBetweenLightAndDark() {
        let light = ColorProbe(PaletteColor.textPrimary.color).relativeLuminance
        let dark = ColorProbe(PaletteColor.textPrimary.darkVariant).relativeLuminance
        XCTAssertLessThan(light, dark, "primary text must get lighter, not darker, in dark mode")
    }

    // MARK: - Typography ramp

    /// The ramp exists so hierarchy is a single decision. Two roles resolving to
    /// the same font silently flattens that hierarchy at every call site.
    func testEveryTypographyRoleHasItsOwnFont() {
        let roles: [Typography] = [.display, .title, .heading, .body, .label, .caption]
        for (outerIndex, outer) in roles.enumerated() {
            for (innerIndex, inner) in roles.enumerated() where innerIndex > outerIndex {
                XCTAssertNotEqual(outer.font, inner.font, "\(outer) and \(inner) resolve to the same font")
            }
        }
    }
}
