//
//  DashboardGamesContent.swift
//  StreakSync
//
//  Games content display with different view modes
//

import SwiftUI

struct DashboardGamesContent: View {
    let filteredGames: [Game]
    let filteredStreaks: [GameStreak]
    let displayMode: GameDisplayMode
    let searchText: String
    let refreshID: UUID
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
                cardView
            case .list:
                listView
            case .compact:
                compactView
            }
        }
    }
    
    // MARK: - View Modes
    
    private var cardView: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(filteredStreaks.enumerated()), id: \.element.id) { index, streak in
                EnhancedStreakCard(
                    streak: streak,
                    hasAppeared: hasInitiallyAppeared,
                    animationIndex: index,
                    isFavorite: gameCatalog.isFavorite(streak.gameId),
                    onFavoriteToggle: {
                        gameCatalog.toggleFavorite(streak.gameId)
                        HapticManager.shared.trigger(.toggleSwitch)
                    }
                ) {
                    if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                        // Add a minimal delay to ensure gesture completion
                        DispatchQueue.main.async {
                            coordinator.navigateTo(.gameDetail(game))
                        }
                    }
                }
                .id("\(refreshID)-\(streak.id)")
            }
        }
        .padding(.horizontal)
    }
    
    private var listView: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredStreaks) { streak in
                GameListItemView(
                    streak: streak,
                    isFavorite: gameCatalog.isFavorite(streak.gameId),
                    onFavoriteToggle: {
                        gameCatalog.toggleFavorite(streak.gameId)
                        HapticManager.shared.trigger(.toggleSwitch)
                    }
                ) {
                    if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                        coordinator.navigateTo(.gameDetail(game))
                    }
                }
                .id("\(refreshID)-\(streak.id)")
            }
        }
        .padding(.horizontal)
    }
    
    private var compactView: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(filteredStreaks) { streak in
                GameCompactCardView(
                    streak: streak,
                    isFavorite: gameCatalog.isFavorite(streak.gameId),
                    onFavoriteToggle: {
                        gameCatalog.toggleFavorite(streak.gameId)
                        HapticManager.shared.trigger(.toggleSwitch)
                    }
                ) {
                    if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                        coordinator.navigateTo(.gameDetail(game))
                    }
                }
                .id("\(refreshID)-\(streak.id)")
            }
        }
        .padding(.horizontal)
    }
}
