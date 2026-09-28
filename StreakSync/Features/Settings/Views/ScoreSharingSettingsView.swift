//
//  ScoreSharingSettingsView.swift
//  StreakSync
//
//  What friends see on the leaderboard: unfinished games, zero-point scores, per-game sharing
//

import SwiftUI

struct ScoreSharingSettingsView: View {
    @EnvironmentObject private var container: AppContainer
    @ObservedObject private var privacy = SocialSettingsService.shared
    @State private var settingsOnAppear: SocialPrivacySettings?

    var body: some View {
        Form {
            Section {
                Toggle("Share unfinished games", isOn: $privacy.settings.shareIncompleteGames)
                Toggle("Hide zero-point scores", isOn: $privacy.settings.hideZeroPointScores)
            } footer: {
                Text("Unfinished games are puzzles you didn't solve.")
            }

            Section {
                ForEach(container.appState.games) { game in
                    Toggle(isOn: $privacy.settings[sharesGame: game.id]) {
                        Label {
                            Text(game.displayName)
                        } icon: {
                            Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                                .foregroundStyle(game.backgroundColor.color)
                                .accessibilityHidden(true)
                        }
                    }
                }
            } header: {
                Text("Share with friends")
            } footer: {
                Text("""
                    Turning a game off also removes the scores you've already shared for it \
                    in the last 30 days.
                    """)
            }
        }
        .navigationTitle("Score Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { settingsOnAppear = privacy.settings }
        .onDisappear(perform: applyChangesToPublishedScores)
    }

    /// Runs once on leaving the screen, so flipping several toggles costs one pass.
    /// Expected flow: reconcileRecentScores retracts published scores the new settings
    /// hide, then republishes recent results they allow again. Skipped for Review Mode and
    /// Guest Mode, whose results are not this account's and must never reach Firestore.
    private func applyChangesToPublishedScores() {
        guard privacy.settings != settingsOnAppear else { return }
        let appState = container.appState
        guard !appState.reviewModeEnabled, !appState.isGuestMode,
              let socialService = container.socialService as? FirebaseSocialService else { return }
        Task {
            await socialService.reconcileRecentScores(
                results: appState.recentResults,
                streaks: appState.streaks
            )
        }
    }
}
