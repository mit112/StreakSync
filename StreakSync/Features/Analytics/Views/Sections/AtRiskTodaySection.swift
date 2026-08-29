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

    /// Names up to three at-risk games, then counts the remainder.
    ///
    /// Extracted from `body` so the arithmetic is testable: it lived inline, uncovered,
    /// and said "and 3 more" when two games were left over, because it subtracted the
    /// two named in the singular branch rather than the three actually listed.
    static func subtitle(for displayNames: [String], namedLimit: Int = 3) -> String {
        let named = displayNames.prefix(namedLimit).joined(separator: ", ")
        let remainder = displayNames.count - namedLimit
        guard remainder > 0 else { return named }
        return "\(named), and \(remainder) more"
    }

    var body: some View {
        if !atRiskGames.isEmpty {
            let count = atRiskGames.count
            let title = count == 1 ? "Don't lose your streak" : "Don't lose your streaks"
            let subtitle = Self.subtitle(for: atRiskGames.map(\.displayName))

            VStack(alignment: .leading, spacing: Spacing.lg) {
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
                                .minTapTarget()
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
