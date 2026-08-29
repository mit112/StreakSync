//
//  WidgetMessageView.swift
//  StreakSyncWidget
//
//  Legible fallback shown when there is no snapshot or no streaks yet
//

import SwiftUI
import WidgetKit

/// Reads as an instruction, never as an error. Two callers:
///
/// - `noData` — the app has never published a snapshot. That is the state of
///   every existing install until it launches the snapshot-writing build once,
///   so it has to look deliberate rather than broken.
/// - `noStreaks` — a snapshot exists but the user has no tracked games yet.
struct WidgetMessageView: View {
    let title: String
    let message: String
    let symbolName: String

    @Environment(\.widgetFamily) private var family

    static let noData = WidgetMessageView(
        title: "No streak data yet",
        message: "Open StreakSync once to start tracking.",
        symbolName: "flame"
    )

    static let noStreaks = WidgetMessageView(
        title: "No streaks yet",
        message: "Share a puzzle result to start one.",
        symbolName: "square.and.arrow.up"
    )

    private var spokenLabel: String {
        "\(title). \(message)"
    }

    var body: some View {
        content
            .widgetURL(WidgetDeepLink.openApp)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text("Open StreakSync")
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            systemBody
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: symbolName)
                .font(.title3)
        }
        .widgetAccentable()
        .accessibilityLabel(spokenLabel)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: WidgetSpacing.hair) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Text("Open StreakSync")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenLabel)
    }

    private var systemBody: some View {
        VStack(alignment: .leading, spacing: WidgetSpacing.row) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(WidgetTint.streak)
            Text(title)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenLabel)
    }
}
