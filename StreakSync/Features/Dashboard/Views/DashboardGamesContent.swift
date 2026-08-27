//
//  DashboardGamesContent.swift
//  StreakSync
//
//  Game card grid/list rendering for the dashboard
//

import SwiftUI

struct DashboardGamesContent: View {
    let filteredGames: [Game]
    let displayMode: GameDisplayMode
    let searchText: String
    let hasInitiallyAppeared: Bool

    @Environment(AppState.self) private var appState
    @Environment(GameCatalog.self) private var gameCatalog
    @EnvironmentObject private var coordinator: NavigationCoordinator

    // Minimum grid item width, scaled with Dynamic Type so the grid collapses to
    // a single column at accessibility sizes instead of staying locked at 2-up (§3).
    @ScaledMetric(relativeTo: .body) private var gridMinItemWidth: CGFloat = 160

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
            ForEach(Array(filteredGames.enumerated()), id: \.element.id) { _, game in
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
                        coordinator.navigateTo(.gameDetail(game))
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
            GridItem(.adaptive(minimum: gridMinItemWidth), spacing: 12)
        ], spacing: 12) {
            ForEach(Array(filteredGames.enumerated()), id: \.element.id) { index, game in
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
        // No inner horizontal padding: the games section already applies
        // `.padding(.horizontal)` in ImprovedDashboardView (§3 double-margin fix).
        // Card mode has never had inner padding — this keeps both modes at 16pt margins.
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ScrollView {
            DashboardGamesContent(
                filteredGames: [Game.wordle, Game.quordle],
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
