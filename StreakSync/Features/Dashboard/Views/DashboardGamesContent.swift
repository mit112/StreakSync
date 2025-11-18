//
//  DashboardGamesContent.swift (Updated)
//  StreakSync
//
//  Updated to use modern game cards
//

import SwiftUI

struct DashboardGamesContent: View {
    let filteredGames: [Game]
    let filteredStreaks: [GameStreak]
    let displayMode: GameDisplayMode
    let searchText: String
    let hasInitiallyAppeared: Bool
    
    @Environment(AppState.self) private var appState
    @Environment(GameCatalog.self) private var gameCatalog
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    var body: some View {
        if filteredGames.isEmpty {
            GameEmptyState(
                title: searchText.isEmpty ? "No games yet" : "No results",
                subtitle: searchText.isEmpty ? "Add games to start tracking" : "Try a different search",
                action: searchText.isEmpty ? {
                    coordinator.navigateTo(.gameManagement)
                } : nil
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            switch displayMode {
            case .card:
                modernCardView
            case .grid:
                modernGridView
            }
        }
    }
    
    // MARK: - Modern Card View
    private var modernCardView: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(filteredGames.enumerated()), id: \.element.id) { index, game in
                // Get streak for this game, or create an empty one if it doesn't exist
                let streak = appState.getStreak(for: game) ?? GameStreak.empty(for: game)
                
                ModernGameCard(
                    streak: streak,
                    game: game,
                    isFavorite: gameCatalog.isFavorite(game.id),
                    onFavoriteToggle: {
                        gameCatalog.toggleFavorite(game.id)
                        HapticManager.shared.trigger(.toggleSwitch)
                    },
                    action: {
                        DispatchQueue.main.async {
                            coordinator.navigateTo(.gameDetail(game))
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .scale)
                ))
                .id(game.id)
            }
        }
    }
    
    // MARK: - Modern Grid View
    private var modernGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(Array(filteredGames.enumerated()), id: \.element.id) { index, game in
                // Get streak for this game, or create an empty one if it doesn't exist
                let streak = appState.getStreak(for: game) ?? GameStreak.empty(for: game)
                
                GameCompactCardView(
                    streak: streak,
                    isFavorite: gameCatalog.isFavorite(game.id),
                    onFavoriteToggle: {
                        gameCatalog.toggleFavorite(game.id)
                        HapticManager.shared.trigger(.toggleSwitch)
                    },
                    onTap: {
                        coordinator.navigateTo(.gameDetail(game))
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.8))
                ))
                .id(game.id)
                .modifier(InitialAnimationModifier(
                    hasAppeared: hasInitiallyAppeared,
                    index: index,
                    totalCount: filteredGames.count
                ))
            }
        }
        .padding(.horizontal, 16)
        // Removed top padding completely
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ScrollView {
            DashboardGamesContent(
                filteredGames: [Game.wordle, Game.quordle],
                filteredStreaks: [
                    GameStreak(
                        gameId: Game.wordle.id,
                        gameName: "wordle",
                        currentStreak: 5,
                        maxStreak: 12,
                        totalGamesPlayed: 30,
                        totalGamesCompleted: 25,
                        lastPlayedDate: Date(),
                        streakStartDate: Date()
                    )
                ],
                displayMode: .card,
                searchText: "",
                hasInitiallyAppeared: true
            )
            .padding()
        }
        .environment(AppState())
        .environment(GameCatalog())
        .environmentObject(NavigationCoordinator())
    }
}
