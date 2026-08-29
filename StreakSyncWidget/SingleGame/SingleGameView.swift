//
//  SingleGameView.swift
//  StreakSyncWidget
//
//  systemSmall body for the configurable single-game widget
//

import SwiftUI
import WidgetKit

struct SingleGameEntryView: View {
    let entry: SingleGameEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var isFullColor: Bool {
        renderingMode == .fullColor
    }

    /// Falls back to the catalog color when the snapshot has no row for this
    /// game — `CodableColor` is in this target's membership precisely for that.
    private var tint: Color {
        guard isFullColor else {
            return .primary
        }
        if let state = entry.state {
            return state.tint
        }
        return entry.game?.backgroundColor.color ?? WidgetTint.streak
    }

    private var displayName: String {
        entry.state?.displayName ?? entry.game?.displayName ?? "StreakSync"
    }

    private var symbolName: String {
        WidgetSymbol.resolve(entry.state?.iconSystemName ?? entry.game?.iconSystemName ?? "")
    }

    private var destination: URL {
        guard let gameID = entry.state?.gameId ?? entry.game?.id else {
            return WidgetDeepLink.openApp
        }
        return WidgetDeepLink.game(id: gameID)
    }

    var body: some View {
        content
            .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if !entry.hasSnapshot {
            WidgetMessageView.noData
        } else {
            VStack(alignment: .leading, spacing: WidgetSpacing.row) {
                header
                streak
                Spacer(minLength: 0)
                status
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(spokenLabel)
            .accessibilityHint("Opens \(displayName) in StreakSync")
            .widgetURL(destination)
        }
    }

    private var header: some View {
        HStack(spacing: WidgetSpacing.tight) {
            Image(systemName: symbolName)
                .font(.footnote)
                .foregroundStyle(tint)
            Text(displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var streak: some View {
        HStack(alignment: .firstTextBaseline, spacing: WidgetSpacing.tight) {
            Image(systemName: "flame.fill")
                .font(.body)
                .foregroundStyle(isFullColor ? WidgetTint.streak : .primary)
            Text(entry.state?.streakText ?? "0")
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

    @ViewBuilder
    private var status: some View {
        if let state = entry.state {
            Label {
                Text(state.statusText)
                    .font(.caption2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: state.statusSymbolName)
                    .font(.caption2)
            }
            .foregroundStyle(isFullColor ? state.statusTint : .secondary)
        } else {
            Text("No results yet")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var spokenLabel: String {
        guard let state = entry.state else {
            return "\(displayName). No results yet."
        }
        return state.accessibilityDescription
    }
}
