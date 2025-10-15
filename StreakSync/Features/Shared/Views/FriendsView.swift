//
//  FriendsView.swift
//  StreakSync
//

import SwiftUI
import UIKit

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var myDisplayName: String = ""
    @Published var myFriendCode: String = ""
    @Published var friendCodeToAdd: String = ""
    @Published var friends: [UserProfile] = []
    @Published var leaderboard: [LeaderboardRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedDateUTC: Date = Date()
    @Published var selectedGameId: UUID? = nil
    @Published var isPresentingAddFriend: Bool = false
    @Published var isPresentingDatePicker: Bool = false
    @Published var currentGamePage: Int = 0
    @Published var range: LeaderboardRange = .today
    @Published var serviceStatus: ServiceStatus = .local
    @Published var isRealTimeEnabled: Bool = false
    
    // Only show games that are actually displayed on the homepage
    var availableGames: [Game] {
        Game.popularGames // Use popular games instead of all available games
    }
    
    private let socialService: SocialService
    private let defaults = UserDefaults.standard
    private let lastDateKey = "friends_last_selected_date"
    private let lastPageKey = "friends_last_game_page"
    private let lastRangeKey = "friends_last_range"
    
    // Real-time refresh timer
    private var refreshTimer: Timer?
    
    init(socialService: SocialService) {
        self.socialService = socialService
        // Restore persisted UI state
        if let saved = defaults.object(forKey: lastDateKey) as? Date { self.selectedDateUTC = saved }
        if let page = defaults.object(forKey: lastPageKey) as? Int { self.currentGamePage = page }
        if let raw = defaults.string(forKey: lastRangeKey), let r = LeaderboardRange(rawValue: raw) { self.range = r }
        
        // Check if this is a hybrid service and get status
        if let hybridService = socialService as? HybridSocialService {
            self.serviceStatus = hybridService.serviceStatus
            self.isRealTimeEnabled = hybridService.isRealTimeEnabled
        }
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let me = try await socialService.ensureProfile(displayName: nil)
            myDisplayName = me.displayName
            myFriendCode = try await socialService.generateFriendCode()
            friends = try await socialService.listFriends()
            let (start, end) = dateRange()
            leaderboard = try await socialService.fetchLeaderboard(startDateUTC: start, endDateUTC: end)
            
            // Setup real-time subscriptions if available
            if let hybridService = socialService as? HybridSocialService {
                await hybridService.setupRealTimeSubscriptions()
                // Update status after setup
                self.serviceStatus = hybridService.serviceStatus
                self.isRealTimeEnabled = hybridService.isRealTimeEnabled
                
                // Start periodic refresh for real-time updates
                if hybridService.isRealTimeEnabled {
                    startPeriodicRefresh()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func refresh() async {
        await load()
    }
    
    func refreshLeaderboard() async {
        do {
            let (start, end) = dateRange()
            leaderboard = try await socialService.fetchLeaderboard(startDateUTC: start, endDateUTC: end)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func addFriend() async {
        let code = friendCodeToAdd
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await socialService.addFriend(using: code)
            friendCodeToAdd = ""
            friends = try await socialService.listFriends()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helpers
    func dateRange() -> (Date, Date) {
        let cal = Calendar(identifier: .gregorian)
        let startDay = cal.startOfDay(for: selectedDateUTC)
        switch range {
        case .today:
            return (startDay, startDay)
        case .sevenDays:
            let end = startDay
            let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
            return (start, end)
        }
    }
    
    func persistUIState() {
        defaults.set(selectedDateUTC, forKey: lastDateKey)
        defaults.set(currentGamePage, forKey: lastPageKey)
        defaults.set(range.rawValue, forKey: lastRangeKey)
    }
    
    // MARK: - Real-time Updates
    
    private func startPeriodicRefresh() {
        stopPeriodicRefresh() // Stop any existing timer
        
        // Refresh every 30 seconds for real-time updates
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshLeaderboard()
            }
        }
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Leaderboard projection for selected game
    func rowsForSelectedGame() -> [(row: LeaderboardRow, points: Int)] {
        var gameId: UUID? = selectedGameId
        if gameId == nil {
            gameId = Game.allAvailableGames.first?.id
        }
        guard let gid = gameId else { return leaderboard.map { ($0, $0.totalPoints) } }
        return leaderboard.map { row in
            let p = row.perGameBreakdown[gid] ?? 0
            return (row, p)
        }.sorted { a, b in
            if a.points == b.points { return a.row.displayName < b.row.displayName }
            return a.points > b.points
        }
    }
    
    func rowsForSelectedGameID(_ gid: UUID) -> [(row: LeaderboardRow, points: Int)] {
        return leaderboard.map { row in
            let p = row.perGameBreakdown[gid] ?? 0
            return (row, p)
        }.sorted { a, b in
            if a.points == b.points { return a.row.displayName < b.row.displayName }
            return a.points > b.points
        }
    }
    
    func attemptsString(for points: Int) -> String {
        // Approximate attempts from points where higher points mean fewer attempts
        // points = maxAttempts - attempts + 1 ⇒ attempts ≈ 7 - points (assuming 6 attempts)
        let attempts = max(1, 7 - max(0, points))
        return "\(attempts) guesses"
    }
}

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
                            dateLabel: formattedDate(viewModel.selectedDateUTC)
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
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
        .refreshable { await viewModel.refresh() }
        .sheet(isPresented: $viewModel.isPresentingAddFriend) { addFriendSheet }
        .task { await viewModel.load() }
        .onChange(of: viewModel.selectedDateUTC) { _, _ in withAnimation(.smooth) { viewModel.persistUIState() } }
        .onChange(of: viewModel.currentGamePage) { _, newValue in withAnimation(.smooth) { viewModel.persistUIState(); viewModel.selectedGameId = viewModel.availableGames[newValue].id } }
        .onChange(of: viewModel.range) { _, _ in withAnimation(.smooth) { Task { await viewModel.refresh() }; viewModel.persistUIState() } }
    }
}

// MARK: - Subviews
private extension FriendsView {
    var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Friends")
                        .font(.largeTitle).bold()
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isRealTimeEnabled ? "icloud.fill" : "externaldrive.fill")
                            .font(.caption)
                            .foregroundStyle(viewModel.isRealTimeEnabled ? .blue : .secondary)
                        Text(viewModel.serviceStatus.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    viewModel.isPresentingDatePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text(formattedDate(viewModel.selectedDateUTC))
                            .font(.headline)
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            rangeToggle
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

// MARK: - Leaderboard Range
enum LeaderboardRange: String { case today, sevenDays }

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
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(0..<totalCount, id: \.self) { index in
                        GameIconView(
                            game: availableGames[index],
                            isActive: index == currentIndex
                        )
                        .frame(width: iconWidth, height: fixedHeight)
                        .id(index)
                        .onTapGesture {
                            onGameSelected(index)
                        }
                    }
                }
                .padding(.horizontal, UIScreen.main.bounds.width / 2 - iconWidth / 2) // Center the first/last icons
                .scrollTargetLayout()
            }
            .frame(height: fixedHeight)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: currentIndex) { oldIndex, newIndex in
                // Only scroll if the index actually changed and is valid
                guard oldIndex != newIndex, 
                      newIndex >= 0, 
                      newIndex < totalCount,
                      oldIndex >= 0 else { return }
                
                // Use a subtle animation with proper scroll target behavior
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
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
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
