//
//  FriendsView.swift
//  StreakSync
//

/*
 * FRIENDSVIEW - SOCIAL COMPETITION AND LEADERBOARD DISPLAY
 * 
 * WHAT THIS FILE DOES:
 * This file creates the main social features screen that displays leaderboards, friend
 * rankings, and competitive elements. It's like a "social dashboard" that shows how
 * users are performing compared to their friends across different games. Think of it
 * as the "competition center" that makes the app more engaging by allowing users to
 * see their rankings, track their progress, and compete with friends.
 * 
 * WHY IT EXISTS:
 * Social features and competition make apps more engaging and encourage users to keep
 * playing. This view provides a comprehensive way to see how users are doing compared
 * to their friends, track their rankings over time, and manage their social connections.
 * It transforms the app from a personal tracking tool into a social, competitive experience.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides the social and competitive features that drive engagement
 * - Displays comprehensive leaderboards for all games
 * - Shows friend rankings and competitive progress
 * - Provides social interaction and friend management
 * - Tracks ranking changes and progress over time
 * - Integrates with the social service for real-time updates
 * - Makes the app more engaging and social
 * 
 * WHAT IT REFERENCES:
 * - FriendsViewModel: Manages the data and business logic for this view
 * - SocialService: For accessing friend data and leaderboards
 * - GameLeaderboardPage: Individual game leaderboard displays
 * - FriendManagementView: For managing friends and social connections
 * - LeaderboardScoring: For calculating and displaying scores
 * - SwiftUI: For UI components, navigation, and interactions
 * 
 * WHAT REFERENCES IT:
 * - MainTabView: This is the main content of the Friends tab
 * - NavigationCoordinator: Can navigate to this view
 * - Social features: All social interactions go through this view
 * - AppContainer: Provides the data and services this view needs
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. VIEW SIZE REDUCTION:
 *    - This file is large (400+ lines) - should be split into smaller components
 *    - Consider separating into: FriendsHeader, LeaderboardContent, FriendManagement
 *    - Move complex logic to separate view models or helper functions
 *    - Create reusable components for common patterns
 * 
 * 2. STATE MANAGEMENT IMPROVEMENTS:
 *    - The current state management is complex - could be simplified
 *    - Consider using a state machine for complex loading states
 *    - Add support for optimistic updates for better user experience
 *    - Implement proper state validation and error handling
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing lazy loading for large leaderboards
 *    - Add view recycling for better memory management
 *    - Implement efficient data fetching and caching
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current interface could be more intuitive
 *    - Add support for different leaderboard views and layouts
 *    - Implement smart sorting and filtering options
 *    - Add support for leaderboard customization and preferences
 * 
 * 5. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for leaderboard logic
 *    - Test different social scenarios and data
 *    - Add UI tests for social interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for social features
 *    - Document the leaderboard system and scoring
 *    - Add examples of how to use different features
 *    - Create social feature flow diagrams
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new social features
 *    - Add support for different leaderboard types
 *    - Implement social feature plugins
 *    - Add support for third-party social integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Social features: Features that allow users to interact with each other
 * - Leaderboards: Rankings that show how users compare to each other
 * - View models: Bridge between UI and business logic
 * - State management: Keeping track of what the UI should show
 * - Tab views: User interfaces that display multiple pages
 * - Social services: Backend services that handle social features
 * - Real-time updates: Information that updates automatically
 * - User experience: Making sure the app is easy and pleasant to use
 * - Accessibility: Making sure the app is usable for everyone
 * - Performance: Making sure the app runs smoothly with lots of data
 */

import SwiftUI
import UIKit

struct FriendsView: View {
    @StateObject private var viewModel: FriendsViewModel
    
    init(socialService: SocialService) {
        _viewModel = StateObject(wrappedValue: FriendsViewModel(socialService: socialService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            TabView(selection: $viewModel.currentGamePage) {
                ForEach(Array(viewModel.availableGames.enumerated()), id: \.offset) { index, game in
                    GeometryReader { proxy in
                        GameLeaderboardPage(
                            game: game,
                            rows: viewModel.rowsForSelectedGameID(game.id),
                            isLoading: viewModel.isLoading,
                            dateLabel: formattedDate(viewModel.selectedDateUTC),
                            rankDelta: viewModel.rankDeltas,
                            onManageFriends: { viewModel.isPresentingManageFriends = true },
                            metricText: { points in
                                LeaderboardScoring.metricLabel(for: game, points: points)
                            },
                            myUserId: viewModel.myUserId,
                            onRefresh: { await viewModel.refresh() }
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(Text("\(game.displayName) leaderboard for \(formattedDate(viewModel.selectedDateUTC))"))
                    }
                    .tag(index)
                    .onAppear {
                        viewModel.selectedGameId = game.id
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .clipped()
            pageDots
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .toolbar { addFriendToolbar }
        .sheet(isPresented: Binding(get: { viewModel.isPresentingAddFriend }, set: { viewModel.isPresentingAddFriend = $0 })) { addFriendSheet }
        .sheet(isPresented: Binding(get: { viewModel.isPresentingManageFriends }, set: { viewModel.isPresentingManageFriends = $0 })) {
            FriendManagementView(socialService: viewModel.socialService)
        }
        .overlay(alignment: .top) {
            if let message = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    Text(message).lineLimit(2)
                    Spacer(minLength: 0)
                    Button("Dismiss") { withAnimation(.easeOut) { viewModel.errorMessage = nil } }
                }
                .font(.caption)
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.selectedDateUTC) { _, _ in withAnimation(.smooth) { viewModel.persistUIState() } }
        .onChange(of: viewModel.currentGamePage) { _, newValue in withAnimation(.smooth) { viewModel.persistUIState(); viewModel.selectedGameId = viewModel.availableGames[newValue].id } }
        .onChange(of: viewModel.range) { _, _ in withAnimation(.smooth) { Task { await viewModel.refresh() }; viewModel.persistUIState() } }
        .safeAreaInset(edge: .bottom) {
            if let summary = viewModel.myRankForSelectedGame() {
                HStack(spacing: 12) {
                    Text("You")
                        .font(.headline)
                    Text("#\(summary.rank)")
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                    Spacer()
                    Text(LeaderboardScoring.metricLabel(for: summary.game, points: summary.points))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Subviews
private extension FriendsView {
    var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Friends").font(.largeTitle.bold())
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isRealTimeEnabled ? "icloud.fill" : "externaldrive.fill")
                            .font(.caption)
                            .foregroundStyle(viewModel.isRealTimeEnabled ? .blue : .secondary)
                        Text(viewModel.serviceStatus.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                if viewModel.serviceStatus == .local {
                    HStack(spacing: 6) {
                        Image(systemName: "wave.3.right").font(.caption)
                        Text("Not syncing. Enable iCloud later to sync across devices.")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    // Segmented range
                    HStack(spacing: 0) {
                        ForEach(LeaderboardRange.allCases, id: \.self) { r in
                            Button(action: {
                                HapticManager.shared.trigger(.toggleSwitch)
                                withAnimation(.smooth) { viewModel.range = r }
                            }) {
                                Text(r == .today ? "Today" : "7 Days")
                                    .font(.subheadline.weight(viewModel.range == r ? .semibold : .regular))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(viewModel.range == r ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .clipShape(Capsule())

                    // Date pager
                    HStack(spacing: 6) {
                        Button(action: { HapticManager.shared.trigger(.pickerChange); viewModel.incrementDay(-1) }) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!viewModel.canIncrementDay(-1))
                        Text(formattedDate(viewModel.selectedDateUTC))
                            .font(.headline)
                            .contentTransition(.numericText())
                            .onLongPressGesture { viewModel.isPresentingDatePicker = true }
                        Button(action: { HapticManager.shared.trigger(.pickerChange); viewModel.incrementDay(1) }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!viewModel.canIncrementDay(1))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            // Centered current game title to mimic NYT styling
            HStack { Spacer(); Text(currentGameTitle).font(.largeTitle.bold()); Spacer() }
        }
        .sheet(isPresented: $viewModel.isPresentingDatePicker) {
            VStack {
                DatePicker("Select Date", selection: $viewModel.selectedDateUTC, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Button("Done") { viewModel.isPresentingDatePicker = false; Task { await viewModel.refresh() } }
                    .padding(.bottom)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Friends leaderboard header"))
    }

    var currentGameTitle: String {
        let idx = viewModel.currentGamePage
        guard Game.allAvailableGames.indices.contains(idx) else { return "" }
        return Game.allAvailableGames[idx].displayName
    }
    
    var rangeToggle: some View {
        HStack(spacing: 12) {
            toggleChip(title: "Today", isSelected: viewModel.range == .today) { viewModel.range = .today }
            toggleChip(title: "7 Days", isSelected: viewModel.range == .sevenDays) { viewModel.range = .sevenDays }
        }
        .padding(.horizontal, 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Leaderboard range"))
    }
    
    func toggleChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { 
            HapticManager.shared.trigger(.toggleSwitch)
            withAnimation(.smooth(duration: 0.3)) { action() } 
        }) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    var pageDots: some View {
        CyclingDotsIndicator(
            currentIndex: viewModel.currentGamePage, 
            totalCount: viewModel.availableGames.count,
            availableGames: viewModel.availableGames,
            onGameSelected: { gameIndex in
                // Let TabView handle the page transition animation naturally
                HapticManager.shared.trigger(.pickerChange)
                viewModel.currentGamePage = gameIndex
                viewModel.selectedGameId = viewModel.availableGames[gameIndex].id
                viewModel.persistUIState()
            }
        )
    }
    
    var addFriendToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.isPresentingAddFriend = true
            } label: {
                Image(systemName: "person.badge.plus")
            }
            .accessibilityLabel(Text("Add friend"))
        }
    }
    
    var addFriendSheet: some View {
        NavigationStack {
            Form {
                Section("Your Code") {
                    HStack {
                        Text(viewModel.myFriendCode).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button("Copy") { UIPasteboard.general.string = viewModel.myFriendCode }
                    }
                }
                Section("Add a Friend") {
                    TextField("Enter friend code", text: $viewModel.friendCodeToAdd)
                    Button("Add") { Task { await viewModel.addFriend() } }
                }
            }
            .navigationTitle("Add Friend")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { viewModel.isPresentingAddFriend = false } } }
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}


// MARK: - Gradient Avatar
struct GradientAvatar: View {
    let initials: String
    var size: CGFloat = 32
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            OptimizedAnimatedGradient(colors: palette(for: initials))
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            Text(initials)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(radius: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
    
    private func palette(for key: String) -> [Color] {
        let palettesLight: [[Color]] = [
            [Color.green, Color.mint, Color.teal],
            [Color.blue, Color.cyan, Color.indigo],
            [Color.orange, Color.pink, Color.red],
            [Color.purple, Color.indigo, Color.blue],
            [Color.yellow, Color.orange, Color.pink]
        ]
        let palettesDark: [[Color]] = [
            [Color.green.opacity(0.8), Color.teal.opacity(0.8), Color.black],
            [Color.blue.opacity(0.8), Color.indigo.opacity(0.8), Color.black],
            [Color.orange.opacity(0.8), Color.red.opacity(0.8), Color.black],
            [Color.purple.opacity(0.8), Color.indigo.opacity(0.8), Color.black],
            [Color.yellow.opacity(0.8), Color.orange.opacity(0.8), Color.black]
        ]
        let palettes = colorScheme == .dark ? palettesDark : palettesLight
        let idx = abs(key.hashValue) % palettes.count
        return palettes[idx]
    }
}

// MARK: - Centered Game Icon Carousel
private struct CyclingDotsIndicator: View {
    let currentIndex: Int
    let totalCount: Int
    let availableGames: [Game]
    let onGameSelected: (Int) -> Void
    
    var body: some View {
        GameIconCarousel(
            currentIndex: currentIndex,
            totalCount: totalCount,
            availableGames: availableGames,
            onGameSelected: onGameSelected
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Game \(currentIndex + 1) of \(max(1, totalCount))"))
    }
}

// MARK: - Game Icon Carousel
private struct GameIconCarousel: View {
    let currentIndex: Int
    let totalCount: Int
    let availableGames: [Game]
    let onGameSelected: (Int) -> Void
    private let iconWidth: CGFloat = 60
    private let spacing: CGFloat = 12
    private let fixedHeight: CGFloat = 50
    @State private var scrollSelection: Int? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(0..<totalCount, id: \.self) { index in
                        GameIconView(
                            game: availableGames[index],
                            isActive: index == (scrollSelection ?? currentIndex)
                        )
                        .frame(width: iconWidth, height: fixedHeight)
                        .id(index)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.1 : 0.95)
                                .opacity(phase.isIdentity ? 1.0 : 0.7)
                        }
                        .onTapGesture {
                            HapticManager.shared.trigger(.pickerChange)
                            if reduceMotion {
                                scrollSelection = index
                            } else {
                                withAnimation(.easeInOut(duration: 0.25)) { scrollSelection = index }
                            }
                            onGameSelected(index)
                        }
                        .accessibilityLabel(Text("\(availableGames[index].displayName), \(index + 1) of \(max(1, totalCount))"))
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: fixedHeight)
            .contentMargins(.horizontal, max(0, geometry.size.width / 2 - iconWidth / 2), for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollSelection)
            .onAppear { scrollSelection = currentIndex }
            .onChange(of: currentIndex) { oldIndex, newIndex in
                guard newIndex != scrollSelection else { return }
                if reduceMotion {
                    scrollSelection = newIndex
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) { scrollSelection = newIndex }
                }
            }
            .onChange(of: scrollSelection) { oldSel, newSel in
                guard let newSel, newSel != currentIndex else { return }
                onGameSelected(newSel)
            }
        }
        .frame(height: fixedHeight)
        .clipped()
        }
    }


// MARK: - Individual Game Icon
private struct GameIconView: View {
    let game: Game
    let isActive: Bool
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Game icon
            Image.safeSystemName(gameIconName, fallback: "gamecontroller")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isActive ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                )
            
            // Game name
            Text(game.displayName)
                .font(.caption2)
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .opacity(isActive ? 1.0 : 0.7)
        .animation(.smooth(duration: 0.3), value: isActive)
        .animation(.smooth(duration: 0.1), value: isPressed)
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: { }
        )
        .accessibilityLabel(Text("\(game.displayName) \(isActive ? "selected" : "" )"))
    }
    
    private var gameIconName: String {
        switch game.displayName.lowercased() {
        case "wordle": return "textformat.abc"
        case "connections": return "puzzlepiece"
        case "mini": return "square.grid.3x3"
        case "spelling bee": return "hexagon" // Fixed: 'bee' symbol doesn't exist
        case "letter boxed": return "square.stack.3d.up"
        case "vertex": return "triangle"
        case "strands": return "link"
        case "dordle": return "textformat.123"
        case "quordle": return "textformat.123"
        case "octordle": return "textformat.123"
        case "absurdle": return "textformat.abc"
        default: return "gamecontroller"
        }
    }
}

// MARK: - Simple shimmering modifier
private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(colors: [.clear, .white.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing)
                    .rotationEffect(.degrees(20))
                    .offset(x: phase)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}

private extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
