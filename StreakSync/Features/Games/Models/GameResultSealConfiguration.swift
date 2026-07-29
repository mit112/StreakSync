//
//  GameResultSealConfiguration.swift
//  StreakSync
//
//  Pure result/game-to-seal text and symbol mapping for the branded result hero
//

import Foundation

struct GameResultSealConfiguration: Equatable {
    let gameName: String
    let gameSystemImage: String
    let score: String
    let statusText: String
    let statusSystemImage: String

    static func make(result: GameResult, game: Game?) -> Self {
        let symbol = game?.iconSystemName
        return .init(
            gameName: game?.displayName ?? result.gameName,
            // A game can carry an empty symbol name, which would render as a blank glyph.
            gameSystemImage: symbol?.isEmpty == false ? (symbol ?? "gamecontroller") : "gamecontroller",
            score: result.displayScore,
            statusText: result.completed ? "Completed" : "Not Completed",
            statusSystemImage: result.completed ? "checkmark.circle.fill" : "xmark.circle.fill"
        )
    }
}
