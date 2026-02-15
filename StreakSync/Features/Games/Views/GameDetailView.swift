//
//  GameDetailView.swift
//  StreakSync
//
//  Game detail screen with streak stats, actions, and recent results
//

import SwiftUI

// MARK: - Game Detail View
struct GameDetailView: View {
    let game: Game
    
    @StateObject internal var viewModel: GameDetailViewModel
    @StateObject private var browserLauncher = BrowserLauncher.shared
    @Environment(AppState.self) internal var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    @State internal var showingManualEntry = false
    @State internal var showingShareSheet = false
    @State internal var isRefreshing = false
    @State internal var isLoadingGame = false
    @State internal var isNavigatingFromNotification = false
    @State internal var isScrolling = false
    
    init(game: Game) {
        self.game = game
        self._viewModel = StateObject(wrappedValue: GameDetailViewModel(gameId: game.id))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                GameDetailHeader(
                    game: game,
                    streak: viewModel.currentStreak,
                    isScrolling: isScrolling
                )
                .staggeredAppearance(index: 0, totalCount: 4)
                
                GameDetailPrimaryActions(
                    game: game,
                    showingManualEntry: $showingManualEntry,
                    isLoadingGame: $isLoadingGame,
                    onPlayGame: playGame
                )
                .staggeredAppearance(index: 1, totalCount: 4)
                
                if !viewModel.recentResults.isEmpty {
                    GameDetailPerformanceView(
                        results: viewModel.recentResults,
                        streak: viewModel.currentStreak
                    )
                    .staggeredAppearance(index: 2, totalCount: 4)
                }
                
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
        .scrollBounceBehavior(.automatic)
        .refreshable {
            await refreshData()
        }
        .navigationTitle(game.displayName)
        .navigationBarTitleDisplayMode(.large)
        .navigationTransition(.automatic)
        .modifier(ScrollPhaseWatcher { _, newPhase in
            isScrolling = newPhase != .idle
        })
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
        .task {
            viewModel.setup(with: appState)
            
            if appState.isNavigatingFromNotification {
                isNavigatingFromNotification = true
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        isNavigatingFromNotification = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView(preSelectedGame: game)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareContent])
        }
        .overlay {
            if isNavigatingFromNotification {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            
                            Text("Loading...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
            }
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
    }
}
