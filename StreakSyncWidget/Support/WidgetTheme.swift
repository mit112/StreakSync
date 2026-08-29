//
//  WidgetTheme.swift
//  StreakSyncWidget
//
//  Widget-local spacing, radius, and tint tokens
//

import SwiftUI

/// Spacing inside a widget. Deliberately tighter than the app's `Spacing` scale:
/// a systemSmall widget is roughly 158pt wide, so the app's 16pt default would
/// spend a tenth of the canvas on a single gutter.
enum WidgetSpacing {
    /// 2pt - between stacked lines of the same thought.
    static let hair: CGFloat = 2

    /// 4pt - inside a chip, between a glyph and its label.
    static let tight: CGFloat = 4

    /// 6pt - between rows and between sibling chips.
    static let row: CGFloat = 6

    /// 10pt - between the header and the content block.
    static let block: CGFloat = 10
}

enum WidgetRadius {
    /// 8pt - game chips. The app's 12pt control radius reads as a pill at chip scale.
    static let chip: CGFloat = 8
}

/// Status tints, mirroring the app's streak vocabulary (`StreakSummaryHero`).
/// Restated here as literals rather than shared: `StreakSyncBrand` lives in the
/// app's Design System, which is not — and should not become — widget membership.
enum WidgetTint {
    /// #FF9F0A — matches `StreakSyncBrand.streak`.
    static let streak = Color(red: 1.0, green: 0.624, blue: 0.039)

    /// #0CA678 — matches `StreakSyncBrand.success`.
    static let success = Color(red: 0.047, green: 0.651, blue: 0.471)

    /// Streak about to break. The app uses system orange for the same state.
    static let atRisk = Color.orange
}
