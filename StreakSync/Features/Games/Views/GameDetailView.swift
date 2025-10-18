//
//  GameDetailView.swift
//  StreakSync
//
//  Unified game detail screen with iOS 26 hero animation support
//

/*
 * GAMEDETAILVIEW - INDIVIDUAL GAME DEEP DIVE AND MANAGEMENT
 * 
 * WHAT THIS FILE DOES:
 * This file creates the detailed view for individual games, showing all the important information
 * about a specific game like Wordle or Quordle. It's like the "game profile page" that displays
 * the user's streak, recent results, performance statistics, and provides quick actions to play
 * the game or add new results. Think of it as the "game dashboard" that gives users a complete
 * overview of their progress and performance for that specific game.
 * 
 * WHY IT EXISTS:
 * Users need a detailed view to see their progress and performance for each individual game.
 * This view provides all the relevant information in one place, making it easy to understand
 * how they're doing and what actions they can take. It also handles the complexity of different
 * iOS versions, providing enhanced features for newer iOS versions while maintaining compatibility
 * with older versions.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides the detailed game view that users interact with most
 * - Shows comprehensive game statistics and performance data
 * - Provides quick actions for playing games and adding results
 * - Displays recent results and streak information
 * - Handles different iOS versions with appropriate features
 * - Integrates with the browser launcher for playing games
 * - Supports manual entry and share sheet functionality
 * 
 * WHAT IT REFERENCES:
 * - GameDetailViewModel: Manages the data and business logic for this view
 * - Game: The specific game being displayed
 * - AppState: Access to game data, results, and streaks
 * - NavigationCoordinator: For navigating to other screens
 * - ThemeManager: For consistent styling and theming
 * - BrowserLauncher: For opening games in the browser
 * - Various game detail components: Header, actions, performance, results
 * 
 * WHAT REFERENCES IT:
 * - MainTabView: Can navigate to this view from the dashboard
 * - NavigationCoordinator: Manages navigation to this view
 * - Game cards: Can navigate to this view when tapped
 * - Deep links: Can navigate directly to this view
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. VIEW SIZE REDUCTION:
 *    - This file is large (400+ lines) - should be split into smaller components
 *    - Consider separating into: GameDetailHeader, GameDetailActions, GameDetailContent
 *    - Move iOS version-specific code to separate files
 *    - Create reusable game detail components
 * 
 * 2. STATE MANAGEMENT IMPROVEMENTS:
 *    - The current state management is complex - could be simplified
 *    - Consider using a state machine for complex loading states
 *    - Add support for optimistic updates for better user experience
 *    - Implement proper state validation and error handling
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider lazy loading for large result sets
 *    - Add view recycling for better memory management
 *    - Implement efficient data fetching and caching
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current interface could be more intuitive
 *    - Add support for different display modes and layouts
 *    - Implement smart defaults based on user behavior
 *    - Add support for customization and personalization
 * 
 * 5. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for game detail logic
 *    - Test different game types and data scenarios
 *    - Add UI tests for game detail interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for game detail features
 *    - Document the data flow and component relationships
 *    - Add examples of how to use different features
 *    - Create game detail flow diagrams
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new game types
 *    - Add support for custom game detail layouts
 *    - Implement game detail plugins
 *    - Add support for third-party game integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Detail views: Screens that show detailed information about a specific item
 * - View models: Bridge between UI and business logic
 * - State management: Keeping track of what the UI should show
 * - iOS version compatibility: Making sure the app works on different iOS versions
 * - Navigation: Moving between different screens in the app
 * - Data binding: Connecting UI elements to data that can change
 * - Async/await: Handling operations that take time to complete
 * - Error handling: What to do when something goes wrong
 * - Accessibility: Making sure the app is usable for everyone
 * - Performance: Making sure the app runs smoothly with lots of data
 */

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
    @State internal var isNavigatingFromNotification = false
    @State internal var isScrolling = false
    
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
                    streak: viewModel.currentStreak,
                    isScrolling: isScrolling
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
        .modifier(ScrollPhaseWatcher { _, newPhase in
            isScrolling = newPhase != .idle
        })
        .navigationTitle(game.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
        .task {
            viewModel.setup(with: appState)
            
            // Check if we're navigating from notification
            if appState.isNavigatingFromNotification {
                isNavigatingFromNotification = true
                
                // Hide loading overlay after data loads
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
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
            // Loading overlay for notification navigation
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
            .environmentObject(ThemeManager.shared)
    }
}

// Remove heroNamespace preview dependency to avoid missing EnvironmentValue errors under Swift 6
