//
//  DashboardGamesSection.swift
//  StreakSync
//
//  Daily games section extracted from DashboardView
//

import SwiftUI

// MARK: - Dashboard Games Section
struct DashboardGamesSection: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    let geometry: GeometryProxy
    
    private var popularGames: [Game] {
        appState.games.filter(\.isPopular)
    }
    
    // Adaptive grid columns based on screen size
    private var gridColumns: [GridItem] {
        let screenWidth = geometry.size.width
        let columnCount = screenWidth > 600 ? 3 : 2 // 3 columns on iPad, 2 on iPhone
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: NSLocalizedString("dashboard.daily_games", comment: "Daily Games"),
                icon: "gamecontroller.fill",
                action: {
                    coordinator.navigateTo(.allStreaks)
                }
            )
            .accessibilityAddTraits(.isHeader)
            
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(popularGames) { game in
                    DashboardGameCard(game: game)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily Games")
    }
}

// MARK: - Dashboard Game Card
struct DashboardGameCard: View {
    let game: Game
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(AppState.self) private var appState
    @StateObject private var browserLauncher = BrowserLauncher.shared
    @State private var showingBrowserSelection = false
    
    private var gameStreak: GameStreak? {
        appState.streaks.first { $0.gameId == game.id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                GameIconView(game: game)
                Spacer()
                PlayButton(game: game, browserLauncher: browserLauncher)
            }
            
            // Game info
            GameInfoView(game: game, streak: gameStreak, browserLauncher: browserLauncher)
            
            Spacer()
        }
        .padding()
        .frame(height: 110)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(game.backgroundColor.color.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            coordinator.navigateTo(.gameDetail(game))
        }
        .contextMenu {
            GameContextMenu(
                game: game,
                browserLauncher: browserLauncher,
                showingBrowserSelection: $showingBrowserSelection
            )
        }

        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view game details")
        .accessibilityAddTraits(.isButton)
    }
    
    private var accessibilityLabel: String {
        let streakText = gameStreak?.displayText ?? "No streak"
        return "\(game.displayName), \(streakText)"
    }
}

// MARK: - Dashboard Game Card
struct CompactGameCard: View {
    let game: Game
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(AppState.self) private var appState
    @StateObject private var browserLauncher = BrowserLauncher.shared
    @State private var showingBrowserSelection = false
    
    private var gameStreak: GameStreak? {
        appState.streaks.first { $0.gameId == game.id }
    }
    
    private var todayResult: GameResult? {
        appState.todaysResults.first { $0.gameId == game.id }
    }
    
    var body: some View {
        Button {
            coordinator.navigateTo(.gameDetail(game))
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(game.backgroundColor.color.gradient)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: game.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                Text(game.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let streak = gameStreak {
                    Text(streak.displayText)
                        .font(.caption)
                        .foregroundStyle(streak.currentStreak > 0 ? .green : .secondary)
                } else {
                    Text("No streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if todayResult != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(makeAccessibilityLabel())
    }
    
    private func makeAccessibilityLabel() -> String {
        let streakText = gameStreak?.displayText ?? "No streak"
        return "\(game.displayName), \(streakText)"
    }
}

// MARK: - Game Icon View
private struct GameIconView: View {
    let game: Game
    
    var body: some View {
        Image(systemName: game.iconSystemName)
            .font(.title2)
            .foregroundStyle(game.backgroundColor.color)
            .accessibilityHidden(true)
    }
}

// MARK: - Play Button
private struct PlayButton: View {
    let game: Game
    let browserLauncher: BrowserLauncher
    
    var body: some View {
        Button {
            browserLauncher.launchGame(game)
        } label: {
            Image(systemName: "play.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(game.backgroundColor.color, in: Circle())
        }
        .accessibilityLabel("Play \(game.displayName)")
    }
}

// MARK: - Game Info View
private struct GameInfoView: View {
    let game: Game
    let streak: GameStreak?
    let browserLauncher: BrowserLauncher
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.displayName)
                .font(.headline)
                .lineLimit(1)
            
            if let streak = streak {
                HStack(spacing: 4) {
                    Image(systemName: streak.streakStatus.iconSystemName)
                        .font(.caption)
                        .foregroundStyle(streak.streakStatus.color)
                        .accessibilityHidden(true)
                    
                    Text(streak.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        }
    }
}

// MARK: - Game Context Menu
private struct GameContextMenu: View {
    let game: Game
    let browserLauncher: BrowserLauncher
    @Binding var showingBrowserSelection: Bool
    @Environment(NavigationCoordinator.self) private var coordinator
    
    var body: some View {
        Group {
            Button {
                coordinator.navigateTo(.gameDetail(game))
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
            
            Button {
                browserLauncher.launchGame(game)
            } label: {
                Label("Play Now", systemImage: "play.fill")
            }
            
            Button {
                showingBrowserSelection = true
            } label: {
                Label("Launch Options...", systemImage: "gear")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GeometryReader { geometry in
        ScrollView {
            DashboardGamesSection(geometry: geometry)
                .environment(AppState())
                .environment(NavigationCoordinator())
                .padding()
        }
    }
}
