//
//  DesignSystemColorProbe.swift
//  StreakSyncTests
//
//  Resolves a SwiftUI Color into sRGB components and WCAG 2.2 contrast ratios.
//

import Foundation
import SwiftUI
import UIKit

/// Test-only probe that reads a `Color` back as sRGB channel values so design
/// tokens can be asserted on. SwiftUI `Color` is opaque; `UIColor` is not.
@MainActor
struct ColorProbe {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    /// `false` when the color could not be expressed in sRGB at all.
    let didResolve: Bool

    init(_ color: Color) {
        var redChannel: CGFloat = 0
        var greenChannel: CGFloat = 0
        var blueChannel: CGFloat = 0
        var alphaChannel: CGFloat = 0
        didResolve = UIColor(color).getRed(
            &redChannel,
            green: &greenChannel,
            blue: &blueChannel,
            alpha: &alphaChannel
        )
        red = Double(redChannel)
        green = Double(greenChannel)
        blue = Double(blueChannel)
        alpha = Double(alphaChannel)
    }

    /// WCAG 2.2 relative luminance, 0.0 (black) ... 1.0 (white).
    var relativeLuminance: Double {
        func linearised(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearised(red) + 0.7152 * linearised(green) + 0.0722 * linearised(blue)
    }

    /// WCAG 2.2 contrast ratio against another color, 1.0 ... 21.0.
    func contrastRatio(against other: ColorProbe) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Sum of the absolute per-channel differences — used to prove two tokens
    /// are not literally the same color.
    func channelDistance(to other: ColorProbe) -> Double {
        abs(red - other.red) + abs(green - other.green) + abs(blue - other.blue)
    }
}
