//
//  FriendsView.swift
//  StreakSync
//
//  Friends tab: leaderboard, requests, and friend management
//

import Combine
import SwiftUI
import UIKit

struct FriendsView: View {
    private enum ActiveFriendsSheet: Identifiable {
        case manage
        case join(initialCode: String?)

        var id: String {
            switch self {
            case .manage:
                return "manage"
            case .join(let initialCode):
                return "join:\(initialCode ?? "")"
            }
        }
    }

    @StateObject private var viewModel: FriendsViewModel
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 44
    @State private var activeSheet: ActiveFriendsSheet?
    /// Nil until the auth subscription first fires, so the very first render reads the live
    /// value instead of showing a signed-in user the sign-in card for one frame.
    @State private var observedIsAnonymous: Bool?
    /// Last authenticated UID seen by the auth subscription. Only updated on non-nil
    /// (signed-in) emissions so a sign-out→re-anon still reads as a genuine identity change.
    @State private var observedUID: String?

    init(socialService: SocialService) {
        _viewModel = StateObject(wrappedValue: FriendsViewModel(socialService: socialService))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .zIndex(10)

            dominantState
                .zIndex(5)

            if showsLeaderboard {
                leaderboardStack
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // `isAnonymous` lives on a nested ObservableObject, so SwiftUI does not observe it
        // through `container`; `receive(on:)` defers until after @Published has settled.
        .onReceive(container.firebaseAuthManager.$currentUser.receive(on: RunLoop.main)) { user in
            observedIsAnonymous = container.firebaseAuthManager.isAnonymous
            // A sign-out→re-anon or an account switch changes the UID while this tab is on
            // screen. Nothing else re-runs `load()` then, so a transient "not authenticated"
            // error stays latched in `errorMessage` until the user leaves and returns.
            // Reloading on the identity change clears it and refetches for the new user.
            // Ignore signed-out (nil) emissions so `observedUID` keeps the last real identity.
            guard let newUID = user?.uid else { return }
            defer { observedUID = newUID }
            if let previous = observedUID, previous != newUID {
                Task { await viewModel.load() }
            }
        }
        .sheet(item: $activeSheet, onDismiss: {
            navigationCoordinator.shouldShowJoinSheet = false
            navigationCoordinator.pendingJoinCode = nil
        }) { sheet in
            switch sheet {
            case .join(let initialCode):
                FriendManagementView(
                    socialService: viewModel.socialService,
                    friendshipChangeTick: viewModel.friendshipChangeTick,
                    initialJoinCode: initialCode
                )
            case .manage:
                FriendManagementView(
                    socialService: viewModel.socialService,
                    friendshipChangeTick: viewModel.friendshipChangeTick
                )
            }
        }
        .onChange(of: navigationCoordinator.shouldShowJoinSheet) { _, shouldShowJoinSheet in
            guard shouldShowJoinSheet else { return }
            activeSheet = .join(initialCode: navigationCoordinator.pendingJoinCode)
        }
        .task {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.friends.count) { _, newCount in
            container.appState.cachedFriendCount = newCount
        }
        .onChange(of: viewModel.selectedDateUTC) { _, _ in
            viewModel.handleSelectedDateChange()
        }
        .onChange(of: viewModel.currentGamePage) { _, newValue in
            withAnimation(.smooth) {
                viewModel.persistUIState()
                viewModel.selectedGameId = viewModel.availableGames[newValue].id
            }
        }
    }
}

// MARK: - Presentation State
private extension FriendsView {
    var currentGame: Game? {
        let index = viewModel.currentGamePage
        guard viewModel.availableGames.indices.contains(index) else { return nil }
        return viewModel.availableGames[index]
    }

    /// Computed once per body pass and reused by both the resolver and the pager.
    var currentRows: [(row: LeaderboardRow, points: Int)] {
        guard let currentGame else { return [] }
        return viewModel.rowsForSelectedGameID(currentGame.id)
    }

    /// A failed cloud sync must still be explained here, because the root
    /// `SyncStatusBanner` is suppressed on this tab (DESIGN_AUDIT §4.5).
    var syncFailureMessage: String? {
        if case .failed = container.gameResultSyncService.syncState {
            return "Sync failed — scores are saved locally"
        }
        return nil
    }

    var presentationState: FriendsPresentationState {
        FriendsPresentationState.resolve(.init(
            isOffline: container.gameResultSyncService.syncState == .offline,
            errorMessage: viewModel.errorMessage ?? syncFailureMessage,
            isAnonymous: observedIsAnonymous ?? container.firebaseAuthManager.isAnonymous,
            isLoading: viewModel.isLoading,
            hasRows: !currentRows.isEmpty,
            hasFriends: !viewModel.friends.isEmpty,
            pendingScoreCount: container.socialService.pendingScoreCount,
            hasCompletedInitialLoad: viewModel.hasLoadedOnce
        ))
    }

    /// Only the initial load hides the pager. `hasRows` is per-current-game, so any state
    /// that unmounted `leaderboardStack` would take the game carousel and paging TabView
    /// with it and leave the user unable to page back to a game that has scores.
    var showsLeaderboard: Bool {
        presentationState != .loading
    }

    /// Exactly one friend-management action is on screen in every state: the page owns it
    /// for `.empty`, the header owns it everywhere else.
    var showsHeaderManageButton: Bool {
        presentationState != .empty
    }

    @ViewBuilder
    var dominantState: some View {
        switch presentationState {
        case .signInRequired:
            SignInBanner(authManager: container.firebaseAuthManager)
                .padding(.bottom, 12)
        case .loading, .offline, .error, .pendingUpload:
            FriendsStateView(
                state: presentationState,
                retry: { await retryLoad() }
            )
            .padding(.bottom, 12)
        case .empty, .populated:
            EmptyView()
        }
    }

    /// Refreshing alone cannot clear an offline/failed `syncState` — only the sync service
    /// mutates it — so Retry has to drive both or the button visibly does nothing.
    func retryLoad() async {
        await viewModel.refresh()
        await container.gameResultSyncService.syncIfNeeded()
    }
}

// MARK: - Subviews
private extension FriendsView {
    // MARK: Header

    var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Friends").font(.largeTitle.bold())
                Spacer()
                if showsHeaderManageButton {
                    Button { presentInviteFlow() } label: {
                        Label("Manage", systemImage: "person.badge.plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel(Text("Manage friends"))
                    .accessibilityIdentifier("friends.manage.button")
                }
            }
            datePager
            Text(currentGameTitle)
                .font(.title.bold())
                .contentTransition(.numericText())
                .animation(.smooth, value: viewModel.currentGamePage)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $viewModel.isPresentingDatePicker) { datePickerSheet }
    }

    // MARK: Shared header components

    var currentGameTitle: String {
        let idx = viewModel.currentGamePage
        guard Game.allAvailableGames.indices.contains(idx) else { return "" }
        return Game.allAvailableGames[idx].displayName
    }

    var datePager: some View {
        HStack(spacing: 12) {
            Button(action: { HapticManager.shared.trigger(.pickerChange); viewModel.incrementDay(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.callout.weight(.semibold))
                    .frame(width: chevronSize, height: chevronSize)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous day")
            .disabled(!viewModel.canIncrementDay(-1))
            .opacity(viewModel.canIncrementDay(-1) ? 1.0 : 0.3)

            Button { viewModel.isPresentingDatePicker = true } label: {
                HStack(spacing: 4) {
                    Text(formattedDate(viewModel.selectedDateUTC))
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: { HapticManager.shared.trigger(.pickerChange); viewModel.incrementDay(1) }) {
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .frame(width: chevronSize, height: chevronSize)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next day")
            .disabled(!viewModel.canIncrementDay(1))
            .opacity(viewModel.canIncrementDay(1) ? 1.0 : 0.3)
        }
    }

    var datePickerSheet: some View {
        VStack(spacing: 0) {
            // Header with Today and Done
            HStack {
                Button("Today") {
                    viewModel.selectedDateUTC = Calendar.current.startOfDay(for: Date())
                    viewModel.isPresentingDatePicker = false
                    Task { await viewModel.refresh() }
                }
                .disabled(Calendar.current.isDateInToday(viewModel.selectedDateUTC))
                Spacer()
                Button("Done") {
                    viewModel.isPresentingDatePicker = false
                    Task { await viewModel.refresh() }
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)

            DatePicker(
                "Select Date",
                selection: $viewModel.selectedDateUTC,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal, 12)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: Leaderboard

    var leaderboardStack: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.currentGamePage) {
                ForEach(Array(viewModel.availableGames.enumerated()), id: \.offset) { index, game in
                    GeometryReader { proxy in
                        GameLeaderboardPage(
                            game: game,
                            rows: viewModel.rowsForSelectedGameID(game.id),
                            notPlayedFriends: viewModel.friendsWhoHaventPlayed(game.id),
                            // Only the genuine first load shows the in-page skeleton; a
                            // background refresh on a later tab visit keeps the last rows
                            // (or the empty/invite state) instead of flashing a skeleton.
                            isLoading: viewModel.isLoading && !viewModel.hasLoadedOnce,
                            dateLabel: formattedDate(viewModel.selectedDateUTC),
                            onManageFriends: { presentInviteFlow() },
                            metricText: { row in
                                LeaderboardScoring.metricLabel(for: game, rawScore: row.perGameRawScore[game.id])
                            },
                            myUserId: viewModel.myUserId,
                            onRefresh: { await viewModel.refresh() },
                            showsInviteAction: showsHeaderManageButton == false
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(Text("\(game.displayName) leaderboard for \(formattedDate(viewModel.selectedDateUTC))"))
                    }
                    .tag(index)
                    .onAppear { viewModel.selectedGameId = game.id }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .clipped()
            GameIconCarousel(
                currentIndex: viewModel.currentGamePage,
                totalCount: viewModel.availableGames.count,
                availableGames: viewModel.availableGames,
                onGameSelected: { gameIndex in
                    HapticManager.shared.trigger(.pickerChange)
                    viewModel.currentGamePage = gameIndex
                    viewModel.selectedGameId = viewModel.availableGames[gameIndex].id
                    viewModel.persistUIState()
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    // MARK: Helpers

    private static let scoreDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        f.dateFormat = "EEE, MMM d, yyyy"
        return f
    }()

    func formattedDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        return Self.scoreDateFormatter.string(from: date)
    }

    func presentInviteFlow() {
        activeSheet = .manage
    }
}
