//
//  DashboardSupportingViews.swift
//  StreakSync
//
//  Shared supporting views used by the Dashboard module
//

import SwiftUI

// MARK: - Game Empty State
struct GameEmptyState: View {
    let title: String
    let subtitle: String
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
                .symbolEffect(.bounce, options: .nonRepeating)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action {
                Button("Add Games", action: action)
                    .buttonStyle(.borderedProminent)
                    .hoverEffect(.lift)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Mini Streak Card
struct MiniStreakCard: View {
    let streak: GameStreak
    let game: Game
    let action: () -> Void

    @State private var isHovered = false

    private var safeIconName: String {
        let iconName = game.iconSystemName
        return iconName.isEmpty ? "gamecontroller" : iconName
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image.safeSystemName(safeIconName, fallback: "gamecontroller")
                    .font(.title2)
                    .foregroundStyle(game.backgroundColor.color)
                    .symbolEffect(.bounce, value: isHovered)

                VStack(spacing: 2) {
                    Text("\(streak.currentStreak)")
                        .font(.headline)
                        .contentTransition(.numericText())
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(game.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .cardStyle(cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .hoverEffect(.highlight)
    }
}
