//
//  GameChipView.swift
//  StreakSyncWidget
//
//  One tappable game row in the medium family
//

import SwiftUI
import WidgetKit

/// Each chip is its own `Link`, so a tap lands on that game's detail screen
/// rather than the app's home tab. `Link` only resolves in the system medium and
/// large families — the small and accessory families use `widgetURL` instead.
struct GameChipView: View {
    let entry: WidgetGameEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    /// Accessory and tinted home-screen modes force monochrome rendering, so the
    /// per-game color is dropped rather than left to be silently flattened.
    private var isFullColor: Bool {
        renderingMode == .fullColor
    }

    var body: some View {
        Link(destination: WidgetDeepLink.game(id: entry.gameId)) {
            HStack(spacing: WidgetSpacing.tight) {
                Image(systemName: WidgetSymbol.resolve(entry.iconSystemName))
                    .font(.caption2)
                    .foregroundStyle(isFullColor ? entry.tint : .primary)
                    .frame(width: 14)

                Text(entry.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: WidgetSpacing.hair)

                Text(entry.streakText)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()

                Image(systemName: entry.statusSymbolName)
                    .font(.caption2)
                    .foregroundStyle(isFullColor ? entry.statusTint : .secondary)
            }
            .padding(.horizontal, WidgetSpacing.row)
            .padding(.vertical, WidgetSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: WidgetRadius.chip, style: .continuous)
                    .fill(.quaternary)
            )
        }
        .accessibilityLabel(entry.accessibilityDescription)
        .accessibilityHint("Opens \(entry.displayName) in StreakSync")
    }
}
