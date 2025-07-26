//
//  AllStreaksView.swift
//  StreakSync
//
//  Simplified all streaks view with clean list design
//

import SwiftUI

// MARK: - All Streaks View
struct AllStreaksView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var searchText = ""
    @State private var selectedFilter: StreakFilter = .all
    
    var body: some View {
        List {
            // Summary section
            summarySection
            
            // Filter section
            filterSection
            
            // Streaks list
            streaksSection
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search games...")
        .navigationTitle("All Streaks")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Sections
    private var summarySection: some View {
        Section {
            HStack(spacing: 0) {
                SummaryStatView(
                    value: "\(activeStreaksCount)",
                    title: "Active",
                    color: .green
                )
                
                Divider()
                    .padding(.vertical, Spacing.sm)
                
                SummaryStatView(
                    value: "\(appState.streaks.count)",
                    title: "Total",
                    color: .blue
                )
                
                Divider()
                    .padding(.vertical, Spacing.sm)
                
                SummaryStatView(
                    value: "\(longestStreak)",
                    title: "Longest",
                    color: .orange
                )
            }
            .padding(.vertical, Spacing.sm)
        }
    }
    
    private var filterSection: some View {
        Section {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(StreakFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var streaksSection: some View {
        Section {
            ForEach(filteredStreaks) { streak in
                StreakListRow(streak: streak)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coordinator.navigateTo(.streakHistory(streak))
                    }
            }
            
            if filteredStreaks.isEmpty {
                EmptyStateMessage()
            }
        }
    }
    
    // MARK: - Computed Properties
    internal var activeStreaksCount: Int {
        appState.streaks.filter { $0.currentStreak > 0 }.count
    }
    
    private var longestStreak: Int {
        appState.streaks.map(\.maxStreak).max() ?? 0
    }
    
    private var filteredStreaks: [GameStreak] {
        let filtered = appState.streaks.filter { streak in
            switch selectedFilter {
            case .all:
                return true
            case .active:
                return streak.currentStreak > 0
            case .inactive:
                return streak.currentStreak == 0
            }
        }
        
        if searchText.isEmpty {
            return filtered.sorted { $0.currentStreak > $1.currentStreak }
        } else {
            return filtered.filter { streak in
                streak.gameName.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.currentStreak > $1.currentStreak }
        }
    }
}

// MARK: - Summary Stat View
struct SummaryStatView: View {
    let value: String
    let title: String
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(
                    title == "Active" ? themeManager.streakActiveColor :
                    title == "Longest" ? themeManager.streakInactiveColor :
                    themeManager.primaryAccent
                )
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: - Streak List Row
struct StreakListRow: View {
    let streak: GameStreak
    @Environment(AppState.self) private var appState
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Game icon
            Image(systemName: game?.iconSystemName ?? "gamecontroller")
                .font(.title3)
                .foregroundStyle(game?.backgroundColor.color ?? .gray)
                .frame(width: 40, height: 40)
            
            // Game info
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.gameName.capitalized)
                    .font(.body)
                
                Text(streak.lastPlayedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Streak info
            VStack(alignment: .trailing, spacing: 2) {
                Text(streak.displayText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(streak.currentStreak > 0 ? .primary : .secondary)
                
                Text(streak.completionPercentage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Empty State Message
struct EmptyStateMessage: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("No streaks found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Streak Filter
enum StreakFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case inactive = "Inactive"
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AllStreaksView()
            .environment(AppState())
            .environment(NavigationCoordinator())
    }
}
