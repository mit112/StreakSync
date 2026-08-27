//
//  GameLeaderboardPage.swift
//  StreakSync
//

import SwiftUI

struct GameLeaderboardPage: View {
    let game: Game
    let rows: [(row: LeaderboardRow, points: Int)]
    let notPlayedFriends: [UserProfile]
    let isLoading: Bool
    let dateLabel: String
    let onManageFriends: () -> Void
    /// Renders the display metric from a leaderboard row (looks up the raw score for
    /// `game`, not the normalized ranking `points`, which can't be mapped back to a
    /// specific attempt/hint/time value).
    let metricText: (LeaderboardRow) -> String
    let myUserId: String?
    let onRefresh: (() async -> Void)?
    /// False when the Friends header already shows Manage, so a state never offers two
    /// friend-management actions at once (DESIGN_AUDIT §4.5).
    let showsInviteAction: Bool
    @State private var pressedIndex: Int?
    @ScaledMetric(relativeTo: .title3) private var rankWidth: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 14
    
    init(
        game: Game,
        rows: [(row: LeaderboardRow, points: Int)],
        notPlayedFriends: [UserProfile] = [],
        isLoading: Bool,
        dateLabel: String,
        onManageFriends: @escaping () -> Void,
        metricText: @escaping (LeaderboardRow) -> String,
        myUserId: String?,
        onRefresh: (() async -> Void)?,
        showsInviteAction: Bool = false
    ) {
        self.game = game
        self.rows = rows
        self.notPlayedFriends = notPlayedFriends
        self.isLoading = isLoading
        self.dateLabel = dateLabel
        self.onManageFriends = onManageFriends
        self.metricText = metricText
        self.myUserId = myUserId
        self.onRefresh = onRefresh
        self.showsInviteAction = showsInviteAction
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            contentView
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            await onRefresh?()
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading && rows.isEmpty {
                // Show a skeleton while loading instead of the "no scores / invite
                // friends" empty state, which otherwise flashed a misleading CTA on
                // first load and every date change.
                SkeletonLoadingView(style: .list)
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .padding(.vertical, 8)
            } else if rows.isEmpty {
                VStack(spacing: 16) {
                    // Game icon as visual anchor
                    ZStack {
                        Circle()
                            .fill(game.backgroundColor.color.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(game.backgroundColor.color.opacity(0.5))
                    }
                    
                    VStack(spacing: 6) {
                        Text("No scores for \(game.displayName)")
                            .font(.headline)
                        Text("Pick a different date or invite friends to compare.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if showsInviteAction {
                        Button {
                            onManageFriends()
                        } label: {
                            Label("Invite friends", systemImage: "person.badge.plus")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
                .padding(.vertical, 8)
            } else {
                ForEach(rows.indices, id: \.self) { index in
                    let entry = rows[index]
                    let isMe = entry.row.userId == myUserId
                    LeaderboardEntryRow(
                        rank: index + 1,
                        displayName: entry.row.displayName,
                        isMe: isMe,
                        metric: metricText(entry.row),
                        streak: entry.row.perGameStreak[game.id]
                    )
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                    // Open rows for everyone else; a rounded tinted surface is reserved for
                    // the current user, so the zebra striping no longer competes with it.
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.control)
                            .fill(rowBackground(isMe: isMe, isPressed: pressedIndex == index))
                    )
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 50, pressing: { pressing in
                        pressedIndex = pressing ? index : nil
                    }, perform: {})
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(accessibilityLabelForRow(index: index, entry: entry)))

                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
            // Friends who haven't played this game yet
            if !notPlayedFriends.isEmpty && !isLoading {
                Text("Hasn't played yet")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
                    .padding(.bottom, 4)
                ForEach(notPlayedFriends) { friend in
                    HStack(spacing: rowSpacing) {
                        Text("–")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                            .frame(width: rankWidth, alignment: .trailing)
                        GradientAvatar(initials: String(friend.displayName.prefix(1)), size: avatarSize)
                            .opacity(0.5)
                        Text(friend.displayName)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            // No bottom management block: the header Manage button (populated) and this
            // page's own "Invite friends" empty state are the only friend-management
            // actions, so a state never offers two of them (DESIGN_AUDIT §4.5).
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension GameLeaderboardPage {
    func rowBackground(isMe: Bool, isPressed: Bool) -> Color {
        if isPressed {
            return Color.secondary.opacity(0.12)
        }
        return isMe ? StreakSyncBrand.primary.opacity(0.10) : .clear
    }

    func accessibilityLabelForRow(index: Int, entry: (row: LeaderboardRow, points: Int)) -> String {
        let rankPart = "Rank \(index + 1)"
        let isMe = entry.row.userId == myUserId
        let namePart = isMe ? "\(entry.row.displayName), Me" : entry.row.displayName
        let metricPart = metricText(entry.row)
        var streakPart = ""
        if let streak = entry.row.perGameStreak[game.id], streak >= 2 {
            streakPart = ", \(streak) day streak"
        }
        return "\(rankPart), \(namePart), \(metricPart)\(streakPart)"
    }
}

// MARK: - Leaderboard Row

/// One leaderboard entry. Standard Dynamic Type sizes keep the single-line
/// rank/avatar/name … score row. In the accessibility text band the rank and
/// avatar grow large enough to crowd out the trailing score, so the score
/// reflows onto its own line instead of clipping off-screen (WCAG 1.4.10).
private struct LeaderboardEntryRow: View {
    let rank: Int
    let displayName: String
    let isMe: Bool
    let metric: String
    let streak: Int?
    @ScaledMetric(relativeTo: .title3) private var rankWidth: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 14
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: rowSpacing))
        layout {
            identity
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            metrics
        }
    }

    private var identity: some View {
        HStack(spacing: rowSpacing) {
            Text("\(rank)")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(rank == 1 ? .primary : .secondary)
                .frame(width: rankWidth, alignment: .trailing)
            GradientAvatar(initials: String(displayName.prefix(1)), size: avatarSize)
            Text(displayName)
                .font(.body.weight(isMe ? .semibold : .regular))
                .lineLimit(1)
            // Text plus tint, so the current user stays identifiable under
            // Differentiate Without Color (DESIGN_AUDIT §4.5).
            if isMe {
                Text("Me")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .foregroundStyle(StreakSyncBrand.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(StreakSyncBrand.primary.opacity(0.12), in: Capsule())
                    .fixedSize()
            }
        }
    }

    private var metrics: some View {
        HStack(spacing: rowSpacing) {
            Text(metric)
                .font(.headline.monospacedDigit())
            if let streak, streak >= 2 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(streak)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
    }
}
