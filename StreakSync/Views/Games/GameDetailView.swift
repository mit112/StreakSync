//
//  GameDetailView.swift
//  StreakSync
//
//  Enhanced game detail with performance visualization and better UX
//

import SwiftUI
import OSLog

// MARK: - Game Detail View
struct GameDetailView: View {
    let game: Game
    @StateObject private var viewModel: GameDetailViewModel
    @StateObject private var browserLauncher = BrowserLauncher.shared
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var showingManualEntry = false
    @State private var showingBrowserOptions = false
    @State private var isLoadingGame = false  // Add this state
    
    init(game: Game) {
        self.game = game
        self._viewModel = StateObject(wrappedValue: GameDetailViewModel(gameId: game.id))
    }
    
    var body: some View {
           ScrollView {
               VStack(spacing: Spacing.xl) {
                   // Enhanced header with stats pills
                   GameDetailHeader(game: game, streak: viewModel.currentStreak)
                   
                   // Primary action - Play button
                   PlayGameButton(
                       game: game,
                       isLoading: isLoadingGame
                   ) {
                       // Action when play button is tapped
                       isLoadingGame = true
                       HapticManager.shared.trigger(.buttonTap)
                       
                       // Launch the game
                       browserLauncher.launchGame(game)
                       
                       // Reset loading state after a short delay
                       DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                           isLoadingGame = false
                       }
                   }
                   
                   // Performance visualization
                   if !viewModel.recentResults.isEmpty {
                       PerformanceSection(
                           results: viewModel.recentResults,
                           onTap: {
                               coordinator.navigateTo(.streakHistory(viewModel.currentStreak))
                           }
                       )
                   }
                
                // Recent results
                if !viewModel.recentResults.isEmpty {
                    RecentResultsSection(results: viewModel.recentResults)
                }
                
                // Secondary actions
                HStack(spacing: Spacing.md) {
                    SecondaryButton(
                        title: "Manual Entry",
                        icon: "keyboard",
                        action: { showingManualEntry = true }
                    )
                    
                    SecondaryButton(
                        title: "Share Stats",
                        icon: "square.and.arrow.up",
                        action: { viewModel.shareGameStats() }
                    )
                }
            }
            .padding(.horizontal, Layout.contentPadding)
            .padding(.vertical, Spacing.xl)
        }
        .navigationTitle(game.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.setup(with: appState)
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
    }
}

// MARK: - Enhanced Game Header
struct GameDetailHeader: View {
    let game: Game
    let streak: GameStreak
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Game icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(game.backgroundColor.color.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: game.iconSystemName)
                    .font(.system(size: 40))
                    .foregroundStyle(game.backgroundColor.color)
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
            
            // Stats pills
            HStack(spacing: Spacing.md) {
                StatPill(
                    value: "\(streak.currentStreak)",
                    label: "Current",
                    color: streak.currentStreak > 0 ? .green : .secondary
                )
                
                StatPill(
                    value: "\(streak.maxStreak)",
                    label: "Best",
                    color: .orange
                )
                
                StatPill(
                    value: streak.completionPercentage,
                    label: "Success",
                    color: .blue
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }
}

// MARK: - Stat Pill
struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Play Game Button (Fixed - no browserLauncher parameter)
struct PlayGameButton: View {
    let game: Game
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                        .font(.title3)
                }
                
                Text(isLoading ? "Opening..." : "Play \(game.displayName)")
                    .font(.headline)
                
                Spacer()
                
                if !isLoading {
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline)
                }
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(game.backgroundColor.color, in: RoundedRectangle(cornerRadius: 12))
            .opacity(isLoading ? 0.8 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "Loading \(game.displayName)" : "Play \(game.displayName)")
        .accessibilityHint("Opens the game")
    }
}

// MARK: - Performance Section
struct PerformanceSection: View {
    let results: [GameResult]
    let onTap: () -> Void
    
    private var last7Days: [DayPerformance] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<7).reversed().map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let dayResult = results.first { result in
                calendar.isDate(result.date, inSameDayAs: date)
            }
            return DayPerformance(date: date, result: dayResult)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Last 7 Days")
                    .font(.headline)
                
                Spacer()
                
                Button("View History") {
                    onTap()
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            
            HStack(spacing: Spacing.sm) {
                ForEach(last7Days, id: \.date) { day in
                    DayIndicator(day: day)
                }
            }
            .padding(Spacing.md)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
        }
    }
}

// MARK: - Day Performance Model
struct DayPerformance {
    let date: Date
    let result: GameResult?
}

// MARK: - Day Indicator
struct DayIndicator: View {
    let day: DayPerformance
    
    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: day.date).prefix(1))
    }
    
    private var indicatorColor: Color {
        guard let result = day.result else { return Color(.systemGray4) }
        return result.completed ? .green : .red
    }
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 2)
                )
            
            Text(dayLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recent Results Section
struct RecentResultsSection: View {
    let results: [GameResult]
    
    private var displayResults: [GameResult] {
        Array(results.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Recent Games")
                .font(.headline)
            
            VStack(spacing: Spacing.sm) {
                ForEach(displayResults) { result in
                    RecentResultRow(result: result)
                }
            }
        }
    }
}

// MARK: - Recent Result Row
struct RecentResultRow: View {
    let result: GameResult
    
    var body: some View {
        HStack {
            Text(result.scoreEmoji)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                
                if let puzzleNumber = result.parsedData["puzzleNumber"] {
                    Text("Puzzle #\(puzzleNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text(result.displayScore)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(result.completed ? .green : .orange)
        }
        .padding(Spacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
        }
        .buttonStyle(.plain)
    }
}



// MARK: - Preview
#Preview {
    NavigationStack {
        GameDetailView(game: Game.wordle)
            .environment(AppState())
            .environment(NavigationCoordinator())
    }
}
