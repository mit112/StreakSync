//
//  MostActiveGamesSection.swift
//  StreakSync
//
//  Most active games ranking for analytics dashboard.
//

import SwiftUI

// MARK: - Most Active Games Section
struct MostActiveGamesSection: View {
    let activeGames: [GameAnalytics]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Most Active Games")
                .font(.headline)
                .fontWeight(.semibold)

            if activeGames.isEmpty {
                EmptyActiveGamesView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(activeGames, id: \.id) { gameAnalytics in
                        MostActiveGameRow(gameAnalytics: gameAnalytics)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

// MARK: - Most Active Game Row
private struct MostActiveGameRow: View {
    let gameAnalytics: GameAnalytics

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(gameAnalytics.game.backgroundColor.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image.safeSystemName(gameAnalytics.game.iconSystemName, fallback: "gamecontroller")
                    .font(.title3)
                    .foregroundStyle(gameAnalytics.game.backgroundColor.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(gameAnalytics.game.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(gameAnalytics.currentStreak) day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(gameAnalytics.totalGamesPlayed)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Games")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty Active Games View
struct EmptyActiveGamesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.title)
                .foregroundStyle(.blue.gradient)

            Text("No Game Activity")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 4) {
                Text("Share game results to start tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Tap the share button after completing a game")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding()
    }
}
