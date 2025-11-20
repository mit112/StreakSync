//
//  GameLeaderboardPage.swift
//  StreakSync
//

/*
 * GAMELEADERBOARDPAGE - COMPETITIVE GAME RANKING AND SOCIAL DISPLAY
 * 
 * WHAT THIS FILE DOES:
 * This file provides a comprehensive leaderboard interface that displays competitive
 * rankings for specific games, showing user positions, scores, and rank changes.
 * It's like a "competitive scoreboard" that creates social engagement and friendly
 * competition among friends. Think of it as the "game ranking system" that makes
 * gaming more social and engaging by showing how users compare to their friends
 * and tracking their progress over time.
 * 
 * WHY IT EXISTS:
 * Social competition is a key driver of user engagement in gaming apps. This component
 * provides a clear, engaging way to display competitive rankings, making users more
 * likely to continue playing and improving their scores. It creates a sense of
 * community and friendly competition that encourages regular app usage and
 * achievement pursuit.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This drives user engagement through social competition
 * - Creates an engaging competitive interface for game rankings
 * - Shows user positions, scores, and rank changes over time
 * - Provides visual feedback for rank improvements and declines
 * - Supports friend management and social features
 * - Makes gaming more social and community-driven
 * - Encourages continued app usage and achievement pursuit
 * 
 * WHAT IT REFERENCES:
 * - Game: Core game data model
 * - LeaderboardRow: Individual leaderboard entry data
 * - GradientAvatar: For displaying user avatars
 * - SwiftUI: For UI components and layout
 * - LazyVStack: For efficient list rendering
 * - Accessibility: For inclusive design
 * 
 * WHAT REFERENCES IT:
 * - Friends views: Use this to display competitive rankings
 * - Game detail views: Use this to show game-specific leaderboards
 * - Social features: Use this for competitive elements
 * - Achievement views: Use this to show competitive achievements
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. LEADERBOARD IMPROVEMENTS:
 *    - The current leaderboard is good but could be more sophisticated
 *    - Consider adding more ranking metrics and variations
 *    - Add support for different leaderboard types and time periods
 *    - Implement smart leaderboard recommendations
 * 
 * 2. SOCIAL FEATURES IMPROVEMENTS:
 *    - The current social features could be enhanced
 *    - Add support for more social interactions and features
 *    - Implement smart social recommendations
 *    - Add support for social tutorials and guidance
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 4. VISUAL DESIGN IMPROVEMENTS:
 *    - The current visual design could be enhanced
 *    - Add support for more sophisticated visual elements
 *    - Implement smart visual adaptation for different contexts
 *    - Add support for dynamic visual elements
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient leaderboard rendering
 *    - Add support for leaderboard caching and reuse
 *    - Implement smart leaderboard management
 * 
 * 6. USER EXPERIENCE IMPROVEMENTS:
 *    - The current leaderboard could be more user-friendly
 *    - Add support for leaderboard customization and preferences
 *    - Implement smart leaderboard recommendations
 *    - Add support for leaderboard tutorials and guidance
 * 
 * 7. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for leaderboard logic
 *    - Test different leaderboard scenarios and configurations
 *    - Add UI tests for leaderboard interactions
 *    - Test accessibility features
 * 
 * 8. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for leaderboard features
 *    - Document the different leaderboard types and usage patterns
 *    - Add examples of how to use different leaderboards
 *    - Create leaderboard usage guidelines
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Leaderboards: Competitive ranking systems that show user positions
 * - Social features: Features that encourage user interaction and competition
 * - User engagement: Keeping users interested and active in the app
 * - Competitive elements: Features that create friendly competition
 * - Visual feedback: Providing users with information about their performance
 * - Accessibility: Making sure leaderboards work for all users
 * - User experience: Making sure competitive features are engaging and fair
 * - Performance: Making sure leaderboards render efficiently
 * - Component libraries: Collections of reusable UI components
 * - Design systems: Standardized approaches to creating consistent experiences
 */

import SwiftUI

struct GameLeaderboardPage: View {
    let game: Game
    let rows: [(row: LeaderboardRow, points: Int)]
    let isLoading: Bool
    let dateLabel: String
    let rankDelta: [String: Int]?
    let onManageFriends: () -> Void
    let metricText: (Int) -> String
    let myUserId: String?
    let onRefresh: (() async -> Void)?
    let onReact: ((LeaderboardRow, Game, ReactionType) -> Void)?
    @State private var pressedIndex: Int? = nil
    @EnvironmentObject private var betaFlags: BetaFeatureFlags
    
    init(
        game: Game,
        rows: [(row: LeaderboardRow, points: Int)],
        isLoading: Bool,
        dateLabel: String,
        rankDelta: [String: Int]?,
        onManageFriends: @escaping () -> Void,
        metricText: @escaping (Int) -> String,
        myUserId: String?,
        onRefresh: (() async -> Void)?,
        onReact: ((LeaderboardRow, Game, ReactionType) -> Void)? = nil
    ) {
        self.game = game
        self.rows = rows
        self.isLoading = isLoading
        self.dateLabel = dateLabel
        self.rankDelta = rankDelta
        self.onManageFriends = onManageFriends
        self.metricText = metricText
        self.myUserId = myUserId
        self.onRefresh = onRefresh
        self.onReact = onReact
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
        LazyVStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 56)
                        .redacted(reason: .placeholder)
                        .padding(.vertical, 6)
                }
            } else if rows.isEmpty {
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
                    // Treat the current user's row as \"Me\" based on myUserId. With the
                    // mapping fix in FriendsViewModel, leaderboard rows now use the same
                    // identifier as `myUserId`, so no heuristic fallback is needed here.
                    let isMe = entry.row.userId == myUserId
                    let displayName = isMe ? "Me" : entry.row.displayName
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .frame(width: 28, alignment: .trailing)
                        GradientAvatar(initials: String(entry.row.displayName.prefix(1)))
                        Text(displayName)
                            .font(.body.weight(isMe ? .semibold : .regular))
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 8) {
                            if betaFlags.rankDeltas, let delta = rankDelta?[entry.row.userId], delta != 0 {
                                Text(delta > 0 ? "↑\(delta)" : "↓\(-delta)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(delta > 0 ? .green : .red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((delta > 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12)), in: Capsule())
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Text(metricText(entry.points))
                        }
                            .font(.headline)
                        if betaFlags.reactions, let onReact {
                            Menu {
                                ForEach(ReactionType.allCases) { reaction in
                                    Button(reaction.emoji) {
                                        onReact(entry.row, game, reaction)
                                    }
                                }
                            } label: {
                                Image(systemName: "face.smiling")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(pressedIndex == index ? 0.12 : (index % 2 == 0 ? 0.04 : 0.0)))
                    )
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 50, pressing: { pressing in
                        pressedIndex = pressing ? index : nil
                    }, perform: {})
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(accessibilityLabelForRow(index: index, entry: entry)))
                    .contentShape(Rectangle())
                    if index != rows.indices.last {
                        Divider()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                Text("Manage friends")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
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
        var deltaPart = ""
        if let delta = rankDelta?[entry.row.userId], delta != 0 {
            deltaPart = delta > 0 ? ", up \(delta) today" : ", down \(-delta) today"
        }
        return "\(rankPart), \(namePart), \(metricPart)\(deltaPart)"
    }
}
