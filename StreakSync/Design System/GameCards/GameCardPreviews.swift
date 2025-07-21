//
//  GameCardPreviews.swift
//  StreakSync
//
//  Created by MiT on 7/23/25.
//

// DesignSystem/GameCards/GameCardPreviews.swift
import SwiftUI

#if DEBUG
struct GameCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            GameCard(
                game: Game.wordle,
                streak: GameStreak(
                    gameId: Game.wordle.id,
                    gameName: "wordle",
                    currentStreak: 15,
                    maxStreak: 23,
                    totalGamesPlayed: 100,
                    totalGamesCompleted: 92,
                    lastPlayedDate: Date(),
                    streakStartDate: Date().addingTimeInterval(-15 * 24 * 60 * 60)
                ),
                todayResult: GameResult(
                    gameId: Game.wordle.id,
                    gameName: "wordle",
                    date: Date(),
                    score: 3,
                    maxAttempts: 6,
                    completed: true,
                    sharedText: "Wordle 942 3/6",
                    parsedData: ["puzzleNumber": "942"]
                )
            ) {
                print("Card tapped")
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Wordle - Light Mode")
            
            // Dark mode preview
            GameCard(
                game: Game.nerdle,
                streak: nil,
                todayResult: nil
            ) {
                print("Card tapped")
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Nerdle - Dark Mode (No Streak)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif
