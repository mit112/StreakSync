//
//  FriendsStateView.swift
//  StreakSync
//
//  One dominant explanation and at most one primary action per Friends trust state
//

import SwiftUI

struct FriendsStateView: View {
    let state: FriendsPresentationState
    let retry: () async -> Void

    // Offline, error, and pending-upload render as a compact strip rather than a
    // `ContentUnavailableView` takeover, because the leaderboard pager stays mounted
    // beneath them: hiding it would strip away the only game-paging control, and a
    // game-result sync failure would hide a leaderboard that loaded fine (§4.5).
    var body: some View {
        switch state {
        case .loading:
            SkeletonLoadingView(style: .list)
                .frame(maxWidth: .infinity, minHeight: 260)
                .padding(.horizontal, 16)

        case .offline(let showingCachedScores):
            statusStrip(
                showingCachedScores
                    ? "You're offline — these are the last scores StreakSync downloaded."
                    : "You're offline. Friends' scores need a connection.",
                systemImage: "wifi.slash",
                tint: StreakSyncBrand.streak,
                showsRetry: true
            )

        case .error(let message, _):
            statusStrip(
                message,
                systemImage: "exclamationmark.triangle.fill",
                tint: StreakSyncBrand.streak,
                showsRetry: true
            )

        case .pendingUpload(let count):
            statusStrip(
                count == 1
                    ? "1 score is waiting to upload, so it isn't on the leaderboard yet."
                    : "\(count) scores are waiting to upload, so they aren't on the leaderboard yet.",
                systemImage: "arrow.triangle.2.circlepath",
                tint: .secondary,
                showsRetry: false
            )

        case .signInRequired, .empty, .populated:
            // Owned by FriendsView: sign-in needs the auth manager, empty is explained by
            // the leaderboard page's own per-game state, and populated needs no status.
            EmptyView()
        }
    }

    private func statusStrip(
        _ message: String,
        systemImage: String,
        tint: Color,
        showsRetry: Bool
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if showsRetry {
                Button("Retry") {
                    Task { await retry() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
    }
}
