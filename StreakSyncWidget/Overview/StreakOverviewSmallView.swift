//
//  StreakOverviewSmallView.swift
//  StreakSyncWidget
//
//  systemSmall: the single most urgent game
//

import SwiftUI
import WidgetKit

/// One game gets the whole canvas: the first at-risk streak, else the longest
/// running one. `Link` does not resolve in systemSmall, so the tap target is the
/// whole widget via `widgetURL`.
struct StreakOverviewSmallView: View {
    let snapshot: WidgetSnapshot

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var isFullColor: Bool {
        renderingMode == .fullColor
    }

    var body: some View {
        if let game = snapshot.mostUrgentGame {
            gameBody(game)
                .widgetURL(WidgetDeepLink.game(id: game.gameId))
        } else {
            WidgetMessageView.noStreaks
        }
    }

    private func gameBody(_ game: WidgetGameEntry) -> some View {
        VStack(alignment: .leading, spacing: WidgetSpacing.row) {
            header(game)
            streakCount(game)
            Spacer(minLength: 0)
            status(game)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(game.accessibilityDescription)
        .accessibilityHint("Opens \(game.displayName) in StreakSync")
    }

    private func header(_ game: WidgetGameEntry) -> some View {
        HStack(spacing: WidgetSpacing.tight) {
            Image(systemName: WidgetSymbol.resolve(game.iconSystemName))
                .font(.footnote)
                .foregroundStyle(isFullColor ? game.tint : .primary)
            Text(game.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func streakCount(_ game: WidgetGameEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: WidgetSpacing.tight) {
            Image(systemName: "flame.fill")
                .font(.body)
                .foregroundStyle(isFullColor ? WidgetTint.streak : .primary)
            Text(game.streakText)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("days")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func status(_ game: WidgetGameEntry) -> some View {
        Label {
            Text(game.statusText)
                .font(.caption2)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        } icon: {
            Image(systemName: game.statusSymbolName)
                .font(.caption2)
        }
        .foregroundStyle(isFullColor ? game.statusTint : .secondary)
    }
}
