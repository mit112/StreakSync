//
//  AllStreaksView.swift
//  StreakSync
//
//  MODERNIZED: iOS 26 native list with enhanced search and materials
//

import SwiftUI

// MARK: - All Streaks View
struct AllStreaksView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var searchText = ""
    @State private var selectedFilter: StreakFilter = .all
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleStreaks: Set<UUID> = []
    
    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26ListView
        } else {
            legacyListView
        }
    }
    
    // MARK: - iOS 26 Implementation
    @available(iOS 26.0, *)
    private var iOS26ListView: some View {
        List {
            // Summary section with iOS 26 materials
            Section {
                iOS26SummaryRow
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Filter section
            Section {
                iOS26FilterPicker
            }
            .listRowBackground(Color.clear)
            
            // Streaks list with iOS 26 animations
            Section {
                ForEach(filteredStreaks) { streak in
                    iOS26StreakRow(streak: streak)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            coordinator.navigateTo(.streakHistory(streak))
                        }
                        .scrollTransition { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.8)
                                .scaleEffect(
                                    x: phase.isIdentity ? 1 : 0.98,
                                    y: phase.isIdentity ? 1 : 0.98
                                )
                        }
                        .onScrollVisibilityChange { isVisible in
                            if isVisible {
                                visibleStreaks.insert(streak.id)
                            }
                        }
                }
                
                if filteredStreaks.isEmpty {
                    iOS26EmptyState
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background {
            // iOS 26 dynamic background
            Rectangle()
                .fill(.background)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
                .ignoresSafeArea()
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search games..."
        )
        .searchSuggestions {
            iOS26SearchSuggestions
        }
        .scrollPosition($scrollPosition)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("All Streaks")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - iOS 26 Summary Row
    @available(iOS 26.0, *)
    private var iOS26SummaryRow: some View {
        HStack(spacing: 0) {
            iOS26SummaryStatView(
                value: "\(activeStreaksCount)",
                title: "Active",
                color: .green,
                icon: "flame.fill"
            )
            
            Divider()
                .padding(.vertical, Spacing.sm)
            
            iOS26SummaryStatView(
                value: "\(appState.streaks.count)",
                title: "Total",
                color: .blue,
                icon: "list.bullet"
            )
            
            Divider()
                .padding(.vertical, Spacing.sm)
            
            iOS26SummaryStatView(
                value: "\(longestStreak)",
                title: "Longest",
                color: .orange,
                icon: "trophy.fill"
            )
        }
        .padding(.vertical, Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - iOS 26 Filter Picker
    @available(iOS 26.0, *)
    private var iOS26FilterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(StreakFilter.allCases, id: \.self) { filter in
                Label(filter.displayName, systemImage: filter.icon)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - iOS 26 Search Suggestions
    @available(iOS 26.0, *)
    @ViewBuilder
    private var iOS26SearchSuggestions: some View {
        if searchText.isEmpty {
            ForEach(recentSearches, id: \.self) { suggestion in
                Label(suggestion, systemImage: "clock.arrow.circlepath")
                    .searchCompletion(suggestion)
            }
        } else {
            ForEach(searchSuggestions, id: \.self) { suggestion in
                Label(suggestion, systemImage: "magnifyingglass")
                    .searchCompletion(suggestion)
            }
        }
    }
    
    @available(iOS 26.0, *)
    struct iOS26StreakRow: View {
        let streak: GameStreak
        @Environment(AppState.self) private var appState
        @State private var isHovered = false
        
        private var game: Game? {
            appState.games.first { $0.id == streak.gameId }
        }
        
        var body: some View {
            HStack(spacing: Spacing.md) {
                // Game icon with animation
                Image(systemName: game?.iconSystemName ?? "gamecontroller")
                    .font(.title3)
                    .foregroundStyle(game?.backgroundColor.color ?? .gray)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(game?.backgroundColor.color.opacity(0.1) ?? Color.gray.opacity(0.1))
                    }
                    .symbolEffect(.bounce, value: isHovered)
                
                // Game info
                VStack(alignment: .leading, spacing: 2) {
                    Text(streak.gameName.capitalized)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(streak.lastPlayedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                // Streak info with badge
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        if streak.currentStreak > 0 {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, options: .repeating.speed(0.5))
                        }
                        
                        Text(streak.displayText)
                            .font(.body.weight(.medium))
                            .foregroundStyle(streak.currentStreak > 0 ? .primary : .secondary)
                            .contentTransition(.numericText())
                    }
                    
                    Text(streak.completionPercentage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal)
            .listRowBackground(
                // FIXED: Using AnyShapeStyle to mix Material and Color
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.clear))
                    .animation(.smooth(duration: 0.2), value: isHovered)
            )
            .listRowSeparator(.hidden)
            .onHover { hovering in
                isHovered = hovering
            }
            .hoverEffect(.highlight)
        }
    }
    
    // MARK: - iOS 26 Empty State
    @available(iOS 26.0, *)
    private var iOS26EmptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, options: .nonRepeating)
            
            Text("No streaks found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !searchText.isEmpty {
                Button("Clear Search") {
                    withAnimation(.smooth) {
                        searchText = ""
                    }
                }
                .buttonStyle(.bordered)
                .hoverEffect(.lift)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .listRowBackground(Color.clear)
    }
    
    // MARK: - iOS 26 Summary Stat View
    @available(iOS 26.0, *)
    struct iOS26SummaryStatView: View {
        let value: String
        let title: String
        let color: Color
        let icon: String
        
        @State private var isPressed = false
        
        var body: some View {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, value: isPressed)
                
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .onTapGesture {
                withAnimation(.smooth(duration: 0.2)) {
                    isPressed.toggle()
                }
            }
        }
    }
    
    // MARK: - Legacy Implementation
    private var legacyListView: some View {
        List {
            // Summary section
            summarySection
            
            // Filter section
            filterSection
            
            // Streaks list
            streaksSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .searchable(text: $searchText, prompt: "Search games...")
        .navigationTitle("All Streaks")
        .navigationBarTitleDisplayMode(.large)
    }
    
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
    private var activeStreaksCount: Int {
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
    
    private var recentSearches: [String] {
        // Mock recent searches - you'd load these from UserDefaults
        ["Wordle", "Connections", "Mini"]
    }
    
    private var searchSuggestions: [String] {
        // Generate suggestions based on current search
        appState.streaks
            .map { $0.gameName }
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .prefix(5)
            .map { String($0) }
    }
    
    // MARK: - Helper Methods
    @MainActor
    private func refreshData() async {
        await appState.refreshData()
    }
}

// MARK: - Supporting Types (Keep existing)
struct SummaryStatView: View {
    let value: String
    let title: String
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

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

// MARK: - Streak Filter (Enhanced)
enum StreakFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case inactive = "Inactive"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .active: return "flame.fill"
        case .inactive: return "pause.circle"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AllStreaksView()
            .environment(AppState())
            .environmentObject(NavigationCoordinator())
            .environmentObject(ThemeManager.shared)
    }
}
