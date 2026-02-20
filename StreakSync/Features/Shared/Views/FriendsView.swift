//
//  FriendsView.swift
//  StreakSync
//

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
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 36
    @State private var activeSheet: ActiveFriendsSheet?
    
    init(socialService: SocialService) {
        _viewModel = StateObject(wrappedValue: FriendsViewModel(socialService: socialService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .zIndex(10)
            SignInBanner(authManager: container.firebaseAuthManager)
                .padding(.bottom, 12)
                .zIndex(5)
            leaderboardStack
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .sheet(item: $activeSheet, onDismiss: {
            navigationCoordinator.shouldShowJoinSheet = false
            navigationCoordinator.pendingJoinCode = nil
        }) { sheet in
            switch sheet {
            case .join(let initialCode):
                FriendManagementView(
                    socialService: viewModel.socialService,
                    initialJoinCode: initialCode
                )
            case .manage:
                FriendManagementView(socialService: viewModel.socialService)
            }
        }
        .onChange(of: navigationCoordinator.shouldShowJoinSheet) { _, shouldShowJoinSheet in
            guard shouldShowJoinSheet else { return }
            activeSheet = .join(initialCode: navigationCoordinator.pendingJoinCode)
        }
        .overlay(alignment: .top) {
            if let message = viewModel.errorMessage {
                errorBanner(message)
            }
        }
        .task {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.cleanup()
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

// MARK: - Subviews
private extension FriendsView {

    // MARK: Header

    var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Friends").font(.largeTitle.bold())
                Spacer()
                Button { presentInviteFlow() } label: {
                    Label("Manage", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel(Text("Manage friends"))
                .accessibilityIdentifier("friends.manage.button")
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
                            isLoading: viewModel.isLoading,
                            dateLabel: formattedDate(viewModel.selectedDateUTC),
                            onManageFriends: { presentInviteFlow() },
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

    // MARK: Error

    func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message).lineLimit(2)
            Spacer(minLength: 0)
            Button("Retry") { Task { await viewModel.refresh() } }
                .buttonStyle(.bordered)
            Button("Dismiss") { withAnimation(.easeOut) { viewModel.errorMessage = nil } }
        }
        .font(.caption)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
        // Keep banner below header controls so it doesn't steal taps from primary actions.
        .padding(.top, 96)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Helpers

    func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        f.dateFormat = "EEE, MMM d, yyyy"
        return f.string(from: date)
    }

    func presentInviteFlow() {
        activeSheet = .manage
    }
}
