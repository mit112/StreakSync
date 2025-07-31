//
//  GameDetailView.swift
//  StreakSync
//
//  Unified game detail screen with all enhancements
//

import SwiftUI

// MARK: - Game Detail View
struct GameDetailView: View {
    let game: Game
    
    @StateObject private var viewModel: GameDetailViewModel
    @StateObject private var browserLauncher = BrowserLauncher.shared
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var showingManualEntry = false
    @State private var showingShareSheet = false
    @State private var isRefreshing = false
    @State private var isLoadingGame = false
    
    init(game: Game) {
        self.game = game
        self._viewModel = StateObject(wrappedValue: GameDetailViewModel(gameId: game.id))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header with animated stats
                GameDetailHeader(
                    game: game,
                    streak: viewModel.currentStreak
                )
                .staggeredAppearance(index: 0, totalCount: 4)
                
                // Primary Actions
                primaryActions
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
                recentResultsSection
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
    
    // MARK: - Primary Actions
    private var primaryActions: some View {
        HStack(spacing: Spacing.md) {
            // Play Game Button
            Button {
                playGame()
            } label: {
                Label("Play \(game.displayName)", systemImage: "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(game.backgroundColor.color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            }
            .pressable(hapticType: .buttonTap)
            .hoverable()
            .disabled(isLoadingGame)
            .overlay {
                if isLoadingGame {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            
            // Manual Entry Button
            Button {
                showingManualEntry = true
            } label: {
                Label("Add Result", systemImage: "keyboard")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .glassCard()
            }
            .pressable(hapticType: .buttonTap)
            .hoverable()
        }
    }
    
    // MARK: - Recent Results Section
    private var recentResultsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label("Recent Results", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                
                if viewModel.recentResults.count > 5 {
                    Button("See All") {
                        coordinator.navigateTo(.streakHistory(viewModel.currentStreak))
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            
            if viewModel.recentResults.isEmpty {
                EmptyResultsCard(gameName: game.displayName) // Pass the game name
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(viewModel.recentResults.prefix(5).enumerated()), id: \.element.id) { index, result in
                        GameResultRow(result: result)
                            .staggeredAppearance(
                                index: index,
                                totalCount: min(viewModel.recentResults.count, 5)
                            )
                    }
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
    private var shareContent: String {
        """
        I'm playing \(game.displayName) on StreakSync!
        🔥 Current Streak: \(viewModel.currentStreak.currentStreak) days
        🏆 Best Streak: \(viewModel.currentStreak.maxStreak) days
        ✅ Success Rate: \(viewModel.currentStreak.completionPercentage)
        
        Track your daily puzzle streaks with StreakSync!
        """
    }
    
    // MARK: - Actions
    private func playGame() {
        isLoadingGame = true
        HapticManager.shared.trigger(.buttonTap)
        
        browserLauncher.launchGame(game)
        
        // Reset loading state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoadingGame = false
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        await viewModel.refreshData()
        await appState.refreshData()
        isRefreshing = false
    }
}

// MARK: - Enhanced Game Detail Header
struct GameDetailHeader: View {
    let game: Game
    let streak: GameStreak
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Animated game icon
            ZStack {
                Circle()
                    .fill(game.backgroundColor.color.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating && streak.isActive ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Image(systemName: game.iconSystemName)
                    .font(.system(size: 44))
                    .foregroundStyle(game.backgroundColor.color)
            }
            .hoverable()
            .onAppear {
                if streak.isActive {
                    isAnimating = true
                }
            }
            
            // Game info
            VStack(spacing: Spacing.xs) {
                Text(game.displayName)
                    .font(.title2.weight(.semibold))
                
                HStack(spacing: Spacing.sm) {
                    Text(game.category.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let lastPlayed = streak.lastPlayedDate {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        
                        Text(lastPlayed.formatted(.relative(presentation: .named)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Animated stats pills
            HStack(spacing: Spacing.md) {
                AnimatedStatPill(
                    value: "\(streak.currentStreak)",
                    label: "Current",
                    color: streak.currentStreak > 0 ? .green : .orange,
                    isActive: streak.isActive
                )
                
                AnimatedStatPill(
                    value: "\(streak.maxStreak)",
                    label: "Best",
                    color: .blue,
                    isActive: false
                )
                
                AnimatedStatPill(
                    value: streak.completionPercentage,
                    label: "Success",
                    color: .purple,
                    isActive: false
                )
            }
        }
        .padding(Spacing.xl)
        .glassCard()
    }
}

// MARK: - Animated Stat Pill
struct AnimatedStatPill: View {
    let value: String
    let label: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(
                    isActive ?
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                    .default,
                    value: isActive
                )
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .glassCard(depth: .subtle)
        .pressable(hapticType: .buttonTap, scaleAmount: 0.95)
    }
}

// MARK: - Game Result Row
struct GameResultRow: View {
    let result: GameResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.displayScore)
                        .font(.headline)
                        .foregroundStyle(result.completed ? .green : .orange)
                    
                    Text(result.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(SpringPreset.snappy, value: isExpanded)
            }
            
            if isExpanded {
                Text(result.sharedText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .glassCard()
        .pressable(hapticType: .buttonTap, scaleAmount: 0.97)
        .onTapGesture {
            withAnimation(SpringPreset.snappy) {
                isExpanded.toggle()
            }
            HapticManager.shared.trigger(.toggleSwitch)
        }
    }
}

// MARK: - Empty Results Card
struct EmptyResultsCard: View {
    let gameName: String // Add parameter
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No results yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Play \(gameName) to see results here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }
}

// MARK: - Share Sheet
//struct ShareSheet: UIViewControllerRepresentable {
//    let activityItems: [Any]
//    
//    func makeUIViewController(context: Context) -> UIActivityViewController {
//        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
//    }
//    
//    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
//}
//
