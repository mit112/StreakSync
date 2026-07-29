//
//  FriendsPresentationState.swift
//  StreakSync
//
//  Pure precedence resolver for the single dominant Friends trust state
//

import Foundation

struct FriendsPresentationContext: Equatable {
    let isOffline: Bool
    let errorMessage: String?
    let isAnonymous: Bool
    let isLoading: Bool
    let hasRows: Bool
    let hasFriends: Bool
    let pendingScoreCount: Int
}

/// One dominant explanation at a time. Friends previously stacked a sign-in banner, an
/// empty state, a local error, and the global sync banner simultaneously, so the user
/// saw four competing accounts of the same situation (DESIGN_AUDIT §4.5).
enum FriendsPresentationState: Equatable {
    case offline(showingCachedScores: Bool)
    case error(message: String, showingCachedScores: Bool)
    case loading
    case signInRequired
    case pendingUpload(count: Int)
    case empty
    case populated

    /// Precedence: offline → error → initial loading → anonymous-empty identity →
    /// pending upload → empty → populated. Cached rows may stay visible beneath an
    /// offline/error explanation, but sign-in and empty prompts stay suppressed while
    /// there is content to show.
    ///
    /// `pendingUpload` outranks `empty` deliberately: a queued score is exactly why the
    /// user's own row is missing, so "invite friends" would be the wrong explanation.
    static func resolve(_ context: FriendsPresentationContext) -> Self {
        if context.isOffline { return .offline(showingCachedScores: context.hasRows) }
        if let message = context.errorMessage, !message.isEmpty {
            return .error(message: message, showingCachedScores: context.hasRows)
        }
        if context.isLoading && !context.hasRows { return .loading }
        if context.isAnonymous && !context.hasRows && !context.hasFriends { return .signInRequired }
        if context.pendingScoreCount > 0 { return .pendingUpload(count: context.pendingScoreCount) }
        if !context.hasRows { return .empty }
        return .populated
    }
}
