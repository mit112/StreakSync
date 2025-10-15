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
                    VStack(spacing: 12) {
                        ForEach(Array(groupedResults.prefix(5).enumerated()), id: \.element.id) { index, groupedResult in
                            GroupedGameResultRow(groupedResult: groupedResult, onDelete: {
                                deleteGroupedResult(groupedResult)
                            })
                            .staggeredAppearance(
                                index: index,
                                totalCount: min(groupedResults.count, 5)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                // Show regular results for other games
                if results.isEmpty {
                    EmptyResultsCard(gameName: game.displayName)
                } else {
                    List {
                        ForEach(Array(results.prefix(5).enumerated()), id: \.element.id) { index, result in
                            GameResultRow(result: result, onDelete: {
                                deleteResult(result)
                            })
                            .staggeredAppearance(
                                index: index,
                                totalCount: min(results.count, 5)
                            )
                            .listRowInsets(EdgeInsets(top: Spacing.sm / 2, leading: 0, bottom: Spacing.sm / 2, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .frame(height: CGFloat(min(results.count, 5)) * 90) // Approximate row height
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
