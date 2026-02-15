//
//  PersonalBestsSection.swift
//  StreakSync
//
//  Personal bests grid for analytics dashboard.
//

import SwiftUI

// MARK: - Personal Bests Section
struct PersonalBestsSection: View {
    let personalBests: [PersonalBest]
    @Environment(\.colorScheme) private var colorScheme

    private var meaningfulPersonalBests: [PersonalBest] {
        personalBests.filter { personalBest in
            switch personalBest.type {
            case .mostGamesInDay:
                return personalBest.value > 1
            case .longestStreak, .bestScore:
                return personalBest.value > 0
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Bests")
                .font(.headline)
                .fontWeight(.semibold)
            Text("Within selected period")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if meaningfulPersonalBests.isEmpty {
                EmptyPersonalBestsView()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(meaningfulPersonalBests, id: \.id) { personalBest in
                        PersonalBestCard(personalBest: personalBest)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

// MARK: - Personal Best Card
struct PersonalBestCard: View {
    let personalBest: PersonalBest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image.safeSystemName(personalBest.type.iconSystemName, fallback: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(personalBest.value)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(personalBest.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let game = personalBest.game {
                Text(game.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        }
    }
}

// MARK: - Empty Personal Bests View
struct EmptyPersonalBestsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(.yellow.gradient)

            Text("No Personal Bests Yet")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: 4) {
                Text("Play games to set your first record!")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("• Longest streaks")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("• Best scores")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .padding()
    }
}
