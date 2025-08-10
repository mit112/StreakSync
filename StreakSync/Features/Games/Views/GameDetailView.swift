//
//  GameDetailView.swift
//  StreakSync
//
//  Unified game detail screen with iOS 26 hero animation support
//

import SwiftUI

// MARK: - Game Detail View
struct GameDetailView: View {
    let game: Game
    
    @StateObject internal var viewModel: GameDetailViewModel
    @StateObject private var browserLauncher = BrowserLauncher.shared
    @Environment(AppState.self) internal var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State internal var showingManualEntry = false
    @State internal var showingShareSheet = false
    @State internal var isRefreshing = false
    @State internal var isLoadingGame = false
    
    // REMOVED: Local namespace - now using environment
    // @Namespace private var heroNamespace  ❌ DELETED
    
    init(game: Game) {
        self.game = game
        self._viewModel = StateObject(wrappedValue: GameDetailViewModel(gameId: game.id))
    }
    
    var body: some View {
        // Use iOS 26 version if available, otherwise fall back to standard
        if #available(iOS 26.0, *) {
            iOS26Body  // No need to pass namespace anymore
        } else {
            standardBody
        }
    }
    
    // MARK: - Standard Body (Pre-iOS 26)
    private var standardBody: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header with animated stats
                GameDetailHeader(
                    game: game,
                    streak: viewModel.currentStreak
                )
                .staggeredAppearance(index: 0, totalCount: 4)
                
                // Primary Actions
                GameDetailPrimaryActions(
                    game: game,
                    showingManualEntry: $showingManualEntry,
                    isLoadingGame: $isLoadingGame,
                    onPlayGame: playGame
                )
                .staggeredAppearance(index: 1, totalCount: 4)
                
                // Performance Section (if we have results)
                if !viewModel.recentResults.isEmpty {
                    GameDetailPerformanceView(
                        results: viewModel.recentResults,
                        streak: viewModel.currentStreak
                    )
                    .staggeredAppearance(index: 2, totalCount: 4)
                }
                
                // Recent Results
                GameDetailRecentResults(
                    game: game,
                    results: viewModel.recentResults,
                    currentStreak: viewModel.currentStreak
                )
                .staggeredAppearance(index: 3, totalCount: 4)
            }
            .padding(.horizontal, Layout.contentPadding)
            .padding(.vertical, Spacing.xl)
        }
        .refreshable {
            await refreshData()
        }
        .navigationTitle(game.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
        .task {
            viewModel.setup(with: appState)
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareContent])
        }
    }
    
    // MARK: - Share Button
    private var shareButton: some View {
        Button {
            showingShareSheet = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .pressable(hapticType: .buttonTap)
    }
    
    // MARK: - Share Content
    internal var shareContent: String {
        """
        I'm playing \(game.displayName) on StreakSync!
        🔥 Current Streak: \(viewModel.currentStreak.currentStreak) days
        🏆 Best Streak: \(viewModel.currentStreak.maxStreak) days
        ✅ Success Rate: \(viewModel.currentStreak.completionPercentage)
        
        Track your daily puzzle streaks with StreakSync!
        """
    }
    
    // MARK: - Actions
    internal func playGame() {
        isLoadingGame = true
        HapticManager.shared.trigger(.buttonTap)
        
        browserLauncher.launchGame(game)
        
        // Reset loading state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoadingGame = false
        }
    }
    
    internal func refreshData() async {
        isRefreshing = true
        await viewModel.refreshData()
        await appState.refreshData()
        isRefreshing = false
    }
}

// MARK: - Preview
#Preview("Standard") {
    NavigationStack {
        GameDetailView(game: Game.wordle)
            .environment(AppState())
            .environmentObject(NavigationCoordinator())
            .environmentObject(ThemeManager.shared)
    }
}

#if swift(>=6.0)
@available(iOS 26.0, *)
#Preview("iOS 26") {
    @Namespace var previewNamespace
    
    NavigationStack {
        GameDetailView(game: Game.wordle)
            .environment(AppState())
            .environmentObject(NavigationCoordinator())
            .environmentObject(ThemeManager.shared)
            .environment(\.heroNamespace, previewNamespace)
    }
}
#endif
