//
//  SocialPrivacySettingsView.swift
//  StreakSync
//

import SwiftUI

struct SocialPrivacySettingsView: View {
    @ObservedObject var service: SocialSettingsService = .shared
    
    var body: some View {
        Form {
            Section("Sharing defaults") {
                Toggle("Share incomplete games", isOn: Binding(
                    get: { service.settings.shareIncompleteGames },
                    set: { service.updateShareIncompleteGames($0) }
                ))
                Toggle("Hide zero-point scores", isOn: Binding(
                    get: { service.settings.hideZeroPointScores },
                    set: { service.updateHideZeroPointScores($0) }
                ))
                Text("Zero-point scores are typically failures or DNFs. Hiding them keeps leaderboards focused on wins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Per-game visibility") {
                ForEach(Game.popularGames) { game in
                    Picker(game.displayName, selection: binding(for: game)) {
                        ForEach(SocialSharingScope.allCases) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                }
            }
        }
        .navigationTitle("Social Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func binding(for game: Game) -> Binding<SocialSharingScope> {
        Binding(
            get: { service.scope(for: game.id) },
            set: { service.updateScope($0, for: game.id) }
        )
    }
}

