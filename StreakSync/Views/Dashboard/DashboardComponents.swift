//
//  Missing Dashboard Components - COMPILER ERROR FIXES
//  StreakSync
//
//  FIXED: All missing view declarations and component issues (SINGLE SOURCE)
//

import SwiftUI

// MARK: - StatCardView (Single Declaration)
struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let accessibilityHint: String?
    
    init(title: String, value: String, icon: String, color: Color, accessibilityHint: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.accessibilityHint = accessibilityHint
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            
            Text(value)
                .font(.title.bold())
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isStaticText)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isStaticText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SectionHeaderView (Single Declaration)
struct SectionHeaderView: View {
    let title: String
    let icon: String
    let action: (() -> Void)?
    
    init(title: String, icon: String, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            if let action = action {
                Button("See All", action: action)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .accessibilityAddTraits(.isButton)
            }
        }
    }
}

// MARK: - TodaysProgressSection (Single Declaration)
struct TodaysProgressSection: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                
                Text("Today's Progress")
                    .font(.headline)
                
                Spacer()
                
                Text("\(appState.todaysResults.count) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if appState.todaysResults.count <= 5 {
                TodayResultsScrollView(results: appState.todaysResults)
            } else {
                TodayResultsSummary(results: appState.todaysResults)
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's Progress")
    }
}

// MARK: - TodayResultsScrollView (Single Declaration)
struct TodayResultsScrollView: View {
    let results: [GameResult]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(results) { result in
                    TodayGameResultCard(result: result)
                }
            }
            .padding(.horizontal, 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's Progress")
    }
}

// MARK: - Today Results Summary (Performance Optimized)
struct TodayResultsSummary: View {
    let results: [GameResult]
    
    private var completedCount: Int {
        results.filter(\.completed).count
    }
    
    private var averageScore: Double {
        let scores = results.compactMap(\.score)
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(completedCount)/\(results.count) games completed")
                    .font(.subheadline.weight(.medium))
                
                if averageScore > 0 {
                    Text(String(format: "Average score: %.1f", averageScore))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button(NSLocalizedString("navigation.see_all", comment: "See All")) {
                // Navigate to detailed view
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's summary: \(completedCount) of \(results.count) games completed")
    }
}

// MARK: - TodayGameResultCard (Single Declaration)
struct TodayGameResultCard: View {
    let result: GameResult
    
    var body: some View {
        VStack(spacing: 4) {
            Text(result.scoreEmoji)
                .font(.title2)
                .accessibilityHidden(true)
            
            Text(result.gameName.capitalized)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            
            Text(result.displayScore)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(result.accessibilityDescription)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - StreakRowView (Single Declaration)
struct StreakRowView: View {
    let streak: GameStreak
    @Environment(NavigationCoordinator.self) private var coordinator
    @StateObject private var browserLauncher = BrowserLauncher.shared
    
    var body: some View {
        HStack {
            Image(systemName: streak.streakStatus.iconSystemName)
                .foregroundStyle(streak.streakStatus.color)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.gameName.capitalized)
                    .font(.subheadline.weight(.medium))
                
                Text("\(streak.completionPercentage) completion rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Quick play button
            Button {
                if let game = Game.popularGames.first(where: { $0.id == streak.gameId }) {
                    browserLauncher.launchGame(game)
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(streak.streakStatus.color, in: Circle())
            }
            .accessibilityLabel("Play \(streak.gameName)")
            
            Text(streak.displayText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(streak.streakStatus.color)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            coordinator.navigateTo(.streakHistory(streak))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streak.gameName), \(streak.displayText), \(streak.completionPercentage) completion rate")
    }
}

// MARK: - Achievement Row View
struct AchievementRowView: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(achievement.displayColor)
                    .frame(width: 44, height: 44)
                
                Image(systemName: achievement.iconSystemName)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.weight(.medium))
                
                if let unlockedDate = achievement.unlockedDate {
                    Text(unlockedDate.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title), unlocked \(achievement.unlockedDate?.formatted(.relative(presentation: .named)) ?? "")")
        .accessibilityAddTraits(.isButton)
    }
}


// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Enhanced Quick Actions Section (Single Declaration)
struct EnhancedQuickActionsSection: View {
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var showingManualEntry = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Quick Actions", icon: "bolt.fill")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    title: "Add Game",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    coordinator.presentSheet(.addCustomGame)
                }
                
                QuickActionButton(
                    title: "Manual Entry",
                    icon: "keyboard.fill",
                    color: .purple
                ) {
                    showingManualEntry = true
                }
                
                QuickActionButton(
                    title: "All Streaks",
                    icon: "list.bullet",
                    color: .green
                ) {
                    coordinator.navigateTo(.allStreaks)
                }
                
                QuickActionButton(
                    title: "Achievements",
                    icon: "trophy.fill",
                    color: .yellow
                ) {
                    coordinator.navigateTo(.achievements)
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
    }
}

// MARK: - TodaysGamesSection (Single Declaration)
struct TodaysGamesSection: View {
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

// MARK: - EnhancedGameCardView (Single Declaration)
struct EnhancedGameCardView: View {
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
            HStack {
                AsyncImage(url: nil) { _ in
                    gameIcon
                } placeholder: {
                    gameIcon
                }
                
                Spacer()
                
                playButton
            }
            
            gameInfo
            
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
            contextMenuContent
        }
        .sheet(isPresented: $showingBrowserSelection) {
//            BrowserSelectionView(game: game)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view game details")
        .accessibilityAddTraits(.isButton)
    }
    
    internal var gameIcon: some View {
        Image(systemName: game.iconSystemName)
            .font(.title2)
            .foregroundStyle(game.backgroundColor.color)
            .accessibilityHidden(true)
    }
    
    private var playButton: some View {
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
    
    private var gameInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.displayName)
                .font(.headline)
                .lineLimit(1)
            
            if let streak = gameStreak {
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
    
    private var contextMenuContent: some View {
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
    
    private var accessibilityLabel: String {
        let streakText = gameStreak?.displayText ?? "No streak"
        return "\(game.displayName), \(streakText)"
    }
}


// MARK: - RecentAchievementsSection (Single Declaration)
struct RecentAchievementsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    
    private var recentAchievements: [Achievement] {
        appState.unlockedAchievements
            .sorted { first, second in
                let firstDate = first.unlockedDate ?? .distantPast
                let secondDate = second.unlockedDate ?? .distantPast
                return firstDate > secondDate
            }
            .prefix(2)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Recent Achievements",
                icon: "trophy.fill",
                action: {
                    coordinator.navigateTo(.achievements)
                }
            )
            .accessibilityAddTraits(.isHeader)
            
            LazyVStack(spacing: 8) {
                ForEach(recentAchievements) { achievement in
                    AchievementRowView(achievement: achievement)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recent Achievements")
    }
}
