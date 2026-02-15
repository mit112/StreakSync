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
    let metricText: (Int) -> String
    let myUserId: String?
    let onRefresh: (() async -> Void)?
    @State private var pressedIndex: Int? = nil
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
        metricText: @escaping (Int) -> String,
        myUserId: String?,
        onRefresh: (() async -> Void)?
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
            if rows.isEmpty {
                VStack(spacing: 12) {
                    Text("No scores for \(game.displayName)")
                        .font(.headline)
                    Text("Pick a different date or invite friends to compare.")
                        .foregroundStyle(.secondary)
                    Button {
                        onManageFriends()
                    } label: {
                        Label("Invite friends", systemImage: "person.badge.plus")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.2), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .padding(.vertical, 8)
            } else {
                ForEach(rows.indices, id: \.self) { index in
                    let entry = rows[index]
                    let isMe = entry.row.userId == myUserId
                    let displayName = isMe ? "Me" : entry.row.displayName
                    HStack(spacing: rowSpacing) {
                        Text("\(index + 1)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(index == 0 ? .primary : .secondary)
                            .frame(width: rankWidth, alignment: .trailing)
                        GradientAvatar(initials: String(entry.row.displayName.prefix(1)), size: avatarSize)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(.body.weight(isMe ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(metricText(entry.points))
                            .font(.headline)
                        // Streak badge
                        if let streak = entry.row.perGameStreak[game.id], streak >= 2 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.caption2)
                                Text("\(streak)")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(pressedIndex == index ? 0.12 : (index % 2 == 0 ? 0.03 : 0.0)))
                    )
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 50, pressing: { pressing in
                        pressedIndex = pressing ? index : nil
                    }, perform: {})
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(accessibilityLabelForRow(index: index, entry: entry)))
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
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.secondary)
                Text("Manage friends")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .contentShape(Rectangle())
            .onTapGesture { onManageFriends() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension GameLeaderboardPage {
    func accessibilityLabelForRow(index: Int, entry: (row: LeaderboardRow, points: Int)) -> String {
        let rankPart = "Rank \(index + 1)"
        let isMe = entry.row.userId == myUserId
        let namePart = isMe ? "Me" : entry.row.displayName
        let metricPart = metricText(entry.points)
        var streakPart = ""
        if let streak = entry.row.perGameStreak[game.id], streak >= 2 {
            streakPart = ", \(streak) day streak"
        }
        return "\(rankPart), \(namePart), \(metricPart)\(streakPart)"
    }
}
