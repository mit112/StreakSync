//
//  AtRiskTodaySection.swift
//  StreakSync
//
//  Shows games with active streaks that haven't been played today.
//

import SwiftUI

// MARK: - At-Risk Today Section
struct AtRiskTodaySection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var atRiskGames: [Game] {
        appState.getGamesAtRisk()
    }

    var body: some View {
        if !atRiskGames.isEmpty {
            let count = atRiskGames.count
            let title = count == 1 ? "Don't lose your streak" : "Don't lose your streaks"
            let names = atRiskGames.prefix(3).map { $0.displayName }.joined(separator: ", ")
            let subtitle = count == 1 ? names : (count <= 3 ? names : "\(names), and \(count - 2) more")

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image.safeSystemName("flame.fill", fallback: "flame")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(atRiskGames, id: \.id) { game in
                            Button {
                                BrowserLauncher.shared.launchGame(game)
                            } label: {
                                HStack(spacing: 6) {
                                    Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                                    Text("Play \(game.displayName)")
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(game.backgroundColor.color.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .cardStyle()
        }
    }
}
