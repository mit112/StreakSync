//
//  GameDetailRecentResults.swift
//  StreakSync
//
//  Recent results section for game detail view
//

import SwiftUI

struct GameDetailRecentResults: View {
    let game: Game
    let results: [GameResult]
    let currentStreak: GameStreak
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            HStack {
                Label("Recent Results", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                
                if results.count > 5 {
                    Button("See All") {
                        coordinator.navigateTo(.streakHistory(currentStreak))
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            
            // Results content
            if results.isEmpty {
                EmptyResultsCard(gameName: game.displayName)
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(results.prefix(5).enumerated()), id: \.element.id) { index, result in
                        GameResultRow(result: result)
                            .staggeredAppearance(
                                index: index,
                                totalCount: min(results.count, 5)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GameDetailRecentResults(
        game: Game.wordle,
        results: [],
        currentStreak: GameStreak(
            gameId: Game.wordle.id,
            gameName: "wordle",
            currentStreak: 5,
            maxStreak: 10,
            totalGamesPlayed: 20,
            totalGamesCompleted: 18,
            lastPlayedDate: Date(),
            streakStartDate: Date()
        )
    )
    .environmentObject(NavigationCoordinator())
    .padding()
}
