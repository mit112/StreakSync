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
    @Environment(AppState.self) private var appState
    
    // Get grouped results for Pips
    private var groupedResults: [GroupedGameResult] {
        appState.getGroupedResults(for: game)
    }
    
    private var isPips: Bool {
        game.name.lowercased() == "pips"
    }
    
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
            if isPips {
                // Show grouped results for Pips
                if groupedResults.isEmpty {
                    EmptyResultsCard(gameName: game.displayName)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(groupedResults.prefix(5).enumerated()), id: \.element.id) { _, groupedResult in
                            GroupedGameResultRow(groupedResult: groupedResult, onDelete: {
                                deleteGroupedResult(groupedResult)
                            })
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: groupedResults.count)
                    .padding(.horizontal, 16)
                }
            } else {
                // Show regular results for other games
                if results.isEmpty {
                    EmptyResultsCard(gameName: game.displayName)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(results.prefix(5).enumerated()), id: \.element.id) { _, result in
                            GameResultRow(result: result, onDelete: {
                                deleteResult(result)
                            })
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: results.count)
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func deleteResult(_ result: GameResult) {
        withAnimation {
            appState.deleteGameResult(result)
        }
        HapticManager.shared.trigger(.achievement)
    }
    
    private func deleteGroupedResult(_ groupedResult: GroupedGameResult) {
        withAnimation {
            // Delete all individual results in the group
            for result in groupedResult.results {
                appState.deleteGameResult(result)
            }
        }
        HapticManager.shared.trigger(.achievement)
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
