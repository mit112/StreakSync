//
//  AllStreaksView.swift
//  StreakSync
//
//  All streaks view — iOS 26 only.
//

import SwiftUI

// MARK: - All Streaks View
struct AllStreaksView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var selectedFilter: StreakFilter = .all
    @State private var scrollPosition = ScrollPosition()

    // MARK: - Body

    var body: some View {
        allStreaksScrollView
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
            .scrollPosition($scrollPosition)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("All Streaks")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await refreshData() }
    }

    // MARK: - Scroll Content

    private var allStreaksScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                summarySection.padding(.horizontal)
                filterSection.padding(.horizontal)
                streaksSection.padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack(spacing: 0) {
            StreakSummaryCard(value: "\(activeStreaksCount)", title: "Active", subtitle: "Streaks",
                             color: .green, icon: "flame.fill", isHighlighted: activeStreaksCount > 0)
            Spacer()
            StreakSummaryCard(value: "\(appState.streaks.count)", title: "Total", subtitle: "Games",
                             color: .blue, icon: "gamecontroller.fill", isHighlighted: false)
            Spacer()
            StreakSummaryCard(value: "\(longestStreak)", title: "Longest", subtitle: "Streak",
                             color: .orange, icon: "trophy.fill", isHighlighted: longestStreak > 0)
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        HStack(spacing: 12) {
            ForEach(StreakFilter.allCases, id: \.self) { filter in
                StreakFilterButton(filter: filter, isSelected: selectedFilter == filter) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedFilter = filter
                    }
                    HapticManager.shared.trigger(.buttonTap)
                }
            }
        }
    }

    // MARK: - Streaks Section

    private var streaksSection: some View {
        LazyVStack(spacing: 12) {
            if filteredStreaks.isEmpty {
                StreakEmptyStateView(searchText: searchText) {
                    withAnimation(.spring()) { searchText = "" }
                }
            } else {
                ForEach(filteredStreaks) { streak in
                    StreakCardView(streak: streak) {
                        coordinator.navigateTo(.streakHistory(streak))
                    }
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.7)
                            .scaleEffect(x: phase.isIdentity ? 1 : 0.95, y: phase.isIdentity ? 1 : 0.95)
                    }
                }
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
            case .all: return true
            case .active: return streak.currentStreak > 0
            case .inactive: return streak.currentStreak == 0
            }
        }
        if searchText.isEmpty {
            return filtered.sorted { $0.currentStreak > $1.currentStreak }
        } else {
            return filtered.filter { $0.gameName.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.currentStreak > $1.currentStreak }
        }
    }

    private var recentSearches: [String] { ["Wordle", "Connections", "Mini"] }

    private var searchSuggestions: [String] {
        appState.streaks.map { $0.gameName }
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .prefix(5).map { String($0) }
    }

    @MainActor
    private func refreshData() async {
        await appState.refreshData()
    }
}

// MARK: - Streak Summary Card

struct StreakSummaryCard: View {
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
            ZStack {
                if isHighlighted {
                    Circle().fill(color.opacity(0.2)).frame(width: 32, height: 32).blur(radius: 8)
                }
                Image.safeSystemName(icon, fallback: "questionmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, value: isPressed)
            }

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())

            VStack(spacing: 2) {
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.primary)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            let borderColor = isHighlighted ? color.opacity(0.3) : Color(.separator).opacity(0.2)
            let borderWidth: CGFloat = isHighlighted ? 1.5 : 0.5
            let shadowColor = isHighlighted ? color.opacity(0.2) : .black.opacity(0.1)

            shape.fill(.ultraThinMaterial)
                .overlay { shape.strokeBorder(borderColor, lineWidth: borderWidth) }
                .shadow(color: shadowColor, radius: isHighlighted ? 8 : 4, x: 0, y: isHighlighted ? 4 : 2)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPressed.toggle() }
        }
    }
}

// MARK: - Streak Filter Button

struct StreakFilterButton: View {
    let filter: StreakFilter
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image.safeSystemName(filter.icon, fallback: "line.3.horizontal.decrease")
                    .font(.caption.weight(.medium))
                Text(filter.displayName).font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(StreakSyncColors.accentGradient(for: colorScheme)) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
                let selectedFill = AnyShapeStyle(StreakSyncColors.primary(for: colorScheme).opacity(0.15))
                let borderColor = isSelected ? StreakSyncColors.primary(for: colorScheme).opacity(0.3) : Color(.separator).opacity(0.2)

                shape.fill(isSelected ? selectedFill : AnyShapeStyle(.ultraThinMaterial))
                    .overlay { shape.strokeBorder(borderColor, lineWidth: isSelected ? 1 : 0.5) }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPressed = pressing }
        }, perform: {})
    }
}

// MARK: - Streak Card View

struct StreakCardView: View {
    let streak: GameStreak
    let action: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var isHovered = false

    private var game: Game? { appState.games.first { $0.id == streak.gameId } }
    private var gameColor: Color { game?.backgroundColor.color ?? .gray }
    private var isActive: Bool { streak.currentStreak > 0 }

    private var completionRate: Int {
        guard streak.totalGamesPlayed > 0 else { return 0 }
        return Int((Double(streak.totalGamesCompleted) / Double(streak.totalGamesPlayed)) * 100)
    }

    private var safeIconName: String {
        guard let iconName = game?.iconSystemName, !iconName.isEmpty else { return "gamecontroller" }
        return iconName
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Game Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [gameColor.opacity(0.2), gameColor.opacity(0.1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Image.safeSystemName(safeIconName, fallback: "gamecontroller")
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
                        if isActive {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill").font(.caption).foregroundStyle(.orange)
                                    .symbolEffect(.pulse, options: .repeating.speed(0.8))
                                Text("\(streak.currentStreak)").font(.caption.weight(.bold)).foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background {
                                Capsule().fill(.orange.opacity(0.15))
                                    .overlay { Capsule().strokeBorder(.orange.opacity(0.3), lineWidth: 1) }
                            }
                        }
                    }

                    // Stats row
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(.green)
                            Text("\(completionRate)%").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        }
                        Text("•").font(.caption).foregroundStyle(.tertiary)
                        Text(streak.lastPlayedText).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if streak.maxStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill").font(.caption2).foregroundStyle(.orange)
                                Text("\(streak.maxStreak)").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.quaternarySystemFill)).frame(height: 4)
                            if isActive {
                                Capsule()
                                    .fill(LinearGradient(colors: [gameColor, gameColor.opacity(0.7)],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: min(geometry.size.width * (Double(streak.currentStreak) / 30.0), geometry.size.width), height: 4)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: streak.currentStreak)
                            }
                        }
                    }
                    .frame(height: 4)
                }

                Image(systemName: "chevron.right").font(.caption.weight(.medium)).foregroundStyle(.tertiary)
            }
            .padding(20)
            .background {
                StreakSyncColors.enhancedGameCardBackground(
                    for: colorScheme, gameColor: gameColor, isActive: isActive, isHovered: isHovered)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPressed = pressing }
        }, perform: {})
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isHovered = hovering }
        }
    }
}

// MARK: - Streak Empty State View

struct StreakEmptyStateView: View {
    let searchText: String
    let onClearSearch: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(StreakSyncColors.primary(for: colorScheme).opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: searchText.isEmpty ? "gamecontroller" : "magnifyingglass")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(StreakSyncColors.primary(for: colorScheme))
                    .symbolEffect(.bounce, options: .nonRepeating)
            }

            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Games Yet" : "No Results Found")
                    .font(.title2.weight(.semibold)).foregroundStyle(.primary)
                Text(searchText.isEmpty ? "Add your first game to start tracking streaks!" : "Try adjusting your search terms")
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            if !searchText.isEmpty {
                Button("Clear Search", action: onClearSearch).buttonStyle(.bordered).controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40).padding(.horizontal, 20)
        .background {
            let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
            shape.fill(.ultraThinMaterial)
                .overlay { shape.strokeBorder(Color(.separator).opacity(0.2), lineWidth: 0.5) }
        }
    }
}

// MARK: - Streak Filter

enum StreakFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case inactive = "Inactive"

    var displayName: String { rawValue }

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
    }
}
