//
//  AllStreaksView.swift
//  StreakSync
//
//  REDESIGNED: Modern glassmorphic cards with enhanced visual hierarchy
//

import SwiftUI

// MARK: - All Streaks View
struct AllStreaksView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(\.colorScheme) private var colorScheme
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
        ScrollView {
            LazyVStack(spacing: 20) {
                // Enhanced Summary Section
                modernSummarySection
                    .padding(.horizontal)
                
                // Modern Filter Picker
                modernFilterSection
                    .padding(.horizontal)
                
                // Streaks Grid/List
                modernStreaksSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background {
            StreakSyncColors.backgroundGradient(for: colorScheme)
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
    
    // MARK: - Modern Summary Section
    @available(iOS 26.0, *)
    private var modernSummarySection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ModernSummaryCard(
                    value: "\(activeStreaksCount)",
                    title: "Active",
                    subtitle: "Streaks",
                    color: .green,
                    icon: "flame.fill",
                    isHighlighted: activeStreaksCount > 0
                )
                
                Spacer()
                
                ModernSummaryCard(
                    value: "\(appState.streaks.count)",
                    title: "Total",
                    subtitle: "Games",
                    color: .blue,
                    icon: "gamecontroller.fill",
                    isHighlighted: false
                )
                
                Spacer()
                
                ModernSummaryCard(
                    value: "\(longestStreak)",
                    title: "Longest",
                    subtitle: "Streak",
                    color: .orange,
                    icon: "trophy.fill",
                    isHighlighted: longestStreak > 0
                )
            }
        }
    }
    
    // MARK: - Modern Filter Section
    @available(iOS 26.0, *)
    private var modernFilterSection: some View {
        HStack(spacing: 12) {
            ForEach(StreakFilter.allCases, id: \.self) { filter in
                ModernFilterButton(
                    filter: filter,
                    isSelected: selectedFilter == filter
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedFilter = filter
                    }
                    HapticManager.shared.trigger(.buttonTap)
                }
            }
        }
    }
    
    // MARK: - Modern Streaks Section
    @available(iOS 26.0, *)
    private var modernStreaksSection: some View {
        LazyVStack(spacing: 12) {
            if filteredStreaks.isEmpty {
                ModernEmptyState(searchText: searchText) {
                    withAnimation(.spring()) {
                        searchText = ""
                    }
                }
            } else {
                ForEach(filteredStreaks) { streak in
                    ModernStreakCard(streak: streak) {
                        coordinator.navigateTo(.streakHistory(streak))
                    }
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.7)
                            .scaleEffect(
                                x: phase.isIdentity ? 1 : 0.95,
                                y: phase.isIdentity ? 1 : 0.95
                            )
                    }
                }
            }
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
        ScrollView {
            LazyVStack(spacing: 20) {
                // Enhanced Summary Section (Legacy)
                legacySummarySection
                    .padding(.horizontal)
                
                // Modern Filter Picker (Legacy)
                legacyFilterSection
                    .padding(.horizontal)
                
                // Streaks List (Legacy)
                legacyStreaksSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background {
            StreakSyncColors.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()
        }
        .searchable(text: $searchText, prompt: "Search games...")
        .navigationTitle("All Streaks")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Legacy Sections
    private var legacySummarySection: some View {
        HStack(spacing: 0) {
            LegacySummaryCard(
                value: "\(activeStreaksCount)",
                title: "Active",
                subtitle: "Streaks",
                color: .green,
                icon: "flame.fill",
                isHighlighted: activeStreaksCount > 0
            )
            
            Spacer()
            
            LegacySummaryCard(
                value: "\(appState.streaks.count)",
                title: "Total",
                subtitle: "Games",
                color: .blue,
                icon: "gamecontroller.fill",
                isHighlighted: false
            )
            
            Spacer()
            
            LegacySummaryCard(
                value: "\(longestStreak)",
                title: "Longest",
                subtitle: "Streak",
                color: .orange,
                icon: "trophy.fill",
                isHighlighted: longestStreak > 0
            )
        }
    }
    
    private var legacyFilterSection: some View {
        HStack(spacing: 12) {
            ForEach(StreakFilter.allCases, id: \.self) { filter in
                LegacyFilterButton(
                    filter: filter,
                    isSelected: selectedFilter == filter
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedFilter = filter
                    }
                    HapticManager.shared.trigger(.buttonTap)
                }
            }
        }
    }
    
    private var legacyStreaksSection: some View {
        LazyVStack(spacing: 12) {
            if filteredStreaks.isEmpty {
                LegacyEmptyState(searchText: searchText) {
                    withAnimation(.spring()) {
                        searchText = ""
                    }
                }
            } else {
                ForEach(filteredStreaks) { streak in
                    LegacyStreakCard(streak: streak) {
                        coordinator.navigateTo(.streakHistory(streak))
                    }
                }
            }
        }
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

// MARK: - Modern Components

// MARK: - Modern Summary Card
@available(iOS 26.0, *)
struct ModernSummaryCard: View {
    let value: String
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
    let isHighlighted: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon with glow effect
            ZStack {
                if isHighlighted {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .blur(radius: 8)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, value: isPressed)
            }
            
            // Value
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            
            // Title and subtitle
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isHighlighted ? 
                                color.opacity(0.3) : 
                                Color(.separator).opacity(0.2),
                            lineWidth: isHighlighted ? 1.5 : 0.5
                        )
                }
                .shadow(
                    color: isHighlighted ? color.opacity(0.2) : .black.opacity(0.05),
                    radius: isHighlighted ? 8 : 4,
                    x: 0,
                    y: isHighlighted ? 4 : 2
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed.toggle()
            }
        }
    }
}

// MARK: - Modern Filter Button
@available(iOS 26.0, *)
struct ModernFilterButton: View {
    let filter: StreakFilter
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption.weight(.medium))
                
                Text(filter.displayName)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(
                isSelected ? 
                    AnyShapeStyle(StreakSyncColors.accentGradient(for: colorScheme)) :
                    AnyShapeStyle(.secondary)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        isSelected ? 
                            AnyShapeStyle(StreakSyncColors.primary(for: colorScheme).opacity(0.15)) :
                            AnyShapeStyle(.ultraThinMaterial)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                isSelected ? 
                                    StreakSyncColors.primary(for: colorScheme).opacity(0.3) :
                                    Color(.separator).opacity(0.2),
                                lineWidth: isSelected ? 1 : 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Modern Streak Card
@available(iOS 26.0, *)
struct ModernStreakCard: View {
    let streak: GameStreak
    let action: () -> Void
    
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var isHovered = false
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    private var gameColor: Color {
        game?.backgroundColor.color ?? .gray
    }
    
    private var isActive: Bool {
        streak.currentStreak > 0
    }
    
    private var completionRate: Int {
        guard streak.totalGamesPlayed > 0 else { return 0 }
        return Int((Double(streak.totalGamesCompleted) / Double(streak.totalGamesPlayed)) * 100)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Game Icon with enhanced styling
                ZStack {
                    // Background circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    gameColor.opacity(0.2),
                                    gameColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    // Icon
                    Image(systemName: game?.iconSystemName ?? "gamecontroller")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(gameColor)
                        .symbolRenderingMode(.hierarchical)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title row
                    HStack {
                        Text(streak.gameName.capitalized)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Active streak indicator
                        if isActive {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .symbolEffect(.pulse, options: .repeating.speed(0.8))
                                
                                Text("\(streak.currentStreak)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(.orange.opacity(0.15))
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                                    }
                            }
                        }
                    }
                    
                    // Stats row
                    HStack(spacing: 12) {
                        // Completion rate
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("\(completionRate)%")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        // Last played
                        Text(streak.lastPlayedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Max streak
                        if streak.maxStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("\(streak.maxStreak)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Capsule()
                                .fill(Color(.quaternarySystemFill))
                                .frame(height: 4)
                            
                            // Progress
                            if isActive {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [gameColor, gameColor.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: min(
                                            geometry.size.width * (Double(streak.currentStreak) / 30.0),
                                            geometry.size.width
                                        ),
                                        height: 4
                                    )
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: streak.currentStreak)
                            }
                        }
                    }
                    .frame(height: 4)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .background {
                StreakSyncColors.enhancedGameCardBackground(
                    for: colorScheme,
                    gameColor: gameColor,
                    isActive: isActive,
                    isHovered: isHovered
                )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Modern Empty State
@available(iOS 26.0, *)
struct ModernEmptyState: View {
    let searchText: String
    let onClearSearch: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon with animation
            ZStack {
                Circle()
                    .fill(StreakSyncColors.primary(for: colorScheme).opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: searchText.isEmpty ? "gamecontroller" : "magnifyingglass")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(StreakSyncColors.primary(for: colorScheme))
                    .symbolEffect(.bounce, options: .nonRepeating)
            }
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Games Yet" : "No Results Found")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(searchText.isEmpty ? 
                     "Add your first game to start tracking streaks!" : 
                     "Try adjusting your search terms")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !searchText.isEmpty {
                Button("Clear Search", action: onClearSearch)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            Color(.separator).opacity(0.2),
                            lineWidth: 0.5
                        )
                }
        }
    }
}

// MARK: - Legacy Components

// MARK: - Legacy Summary Card
struct LegacySummaryCard: View {
    let value: String
    let title: String
    let subtitle: String
    let color: Color
    let icon: String
    let isHighlighted: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            
            // Value
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            
            // Title and subtitle
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StreakSyncColors.cardBackground(for: colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isHighlighted ? 
                                color.opacity(0.3) : 
                                Color(.separator).opacity(0.2),
                            lineWidth: isHighlighted ? 1.5 : 0.5
                        )
                }
                .shadow(
                    color: isHighlighted ? color.opacity(0.2) : .black.opacity(0.05),
                    radius: isHighlighted ? 8 : 4,
                    x: 0,
                    y: isHighlighted ? 4 : 2
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed.toggle()
            }
        }
    }
}

// MARK: - Legacy Filter Button
struct LegacyFilterButton: View {
    let filter: StreakFilter
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption.weight(.medium))
                
                Text(filter.displayName)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(
                isSelected ? 
                    StreakSyncColors.primary(for: colorScheme) :
                    .secondary
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        isSelected ? 
                            AnyShapeStyle(StreakSyncColors.primary(for: colorScheme).opacity(0.15)) :
                            AnyShapeStyle(StreakSyncColors.cardBackground(for: colorScheme))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                isSelected ? 
                                    StreakSyncColors.primary(for: colorScheme).opacity(0.3) :
                                    Color(.separator).opacity(0.2),
                                lineWidth: isSelected ? 1 : 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Legacy Streak Card
struct LegacyStreakCard: View {
    let streak: GameStreak
    let action: () -> Void
    
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    private var gameColor: Color {
        game?.backgroundColor.color ?? .gray
    }
    
    private var isActive: Bool {
        streak.currentStreak > 0
    }
    
    private var completionRate: Int {
        guard streak.totalGamesPlayed > 0 else { return 0 }
        return Int((Double(streak.totalGamesCompleted) / Double(streak.totalGamesPlayed)) * 100)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Game Icon
                ZStack {
                    Circle()
                        .fill(gameColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: game?.iconSystemName ?? "gamecontroller")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(gameColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title row
                    HStack {
                        Text(streak.gameName.capitalized)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Active streak indicator
                        if isActive {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                
                                Text("\(streak.currentStreak)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(.orange.opacity(0.15))
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
                                    }
                            }
                        }
                    }
                    
                    // Stats row
                    HStack(spacing: 12) {
                        // Completion rate
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("\(completionRate)%")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        // Last played
                        Text(streak.lastPlayedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Max streak
                        if streak.maxStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("\(streak.maxStreak)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Capsule()
                                .fill(Color(.quaternarySystemFill))
                                .frame(height: 4)
                            
                            // Progress
                            if isActive {
                                Capsule()
                                    .fill(gameColor)
                                    .frame(
                                        width: min(
                                            geometry.size.width * (Double(streak.currentStreak) / 30.0),
                                            geometry.size.width
                                        ),
                                        height: 4
                                    )
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: streak.currentStreak)
                            }
                        }
                    }
                    .frame(height: 4)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .background {
                StreakSyncColors.gameListItemBackground(for: colorScheme)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Legacy Empty State
struct LegacyEmptyState: View {
    let searchText: String
    let onClearSearch: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(StreakSyncColors.primary(for: colorScheme).opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: searchText.isEmpty ? "gamecontroller" : "magnifyingglass")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(StreakSyncColors.primary(for: colorScheme))
            }
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Games Yet" : "No Results Found")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(searchText.isEmpty ? 
                     "Add your first game to start tracking streaks!" : 
                     "Try adjusting your search terms")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !searchText.isEmpty {
                Button("Clear Search", action: onClearSearch)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(StreakSyncColors.cardBackground(for: colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            Color(.separator).opacity(0.2),
                            lineWidth: 0.5
                        )
                }
        }
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
