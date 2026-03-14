//
//  GameResultParser.swift
//  StreakSync
//
//  Game result parser — routes to per-category extensions
//

import Foundation

// MARK: - Game Result Parser
struct GameResultParser {
    
    func parse(_ text: String, for game: Game) throws -> GameResult {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch game.name.lowercased() {
        case Game.Names.wordle:
            return try parseWordle(cleanText, gameId: game.id)
        case Game.Names.quordle:
            return try parseQuordle(cleanText, gameId: game.id)
        case Game.Names.nerdle:
            return try parseNerdle(cleanText, gameId: game.id)
        case Game.Names.pips:
            return try parsePips(cleanText, gameId: game.id)
        case Game.Names.connections:
            return try parseConnections(cleanText, gameId: game.id)
        case Game.Names.spellingBee:
            return try parseSpellingBee(cleanText, gameId: game.id)
        case Game.Names.miniCrossword:
            return try parseMiniCrossword(cleanText, gameId: game.id)
        case Game.Names.strands:
            return try parseStrands(cleanText, gameId: game.id)
        // LinkedIn Games
        case Game.Names.linkedinQueens:
            return try parseLinkedInQueens(cleanText, gameId: game.id)
        case Game.Names.linkedinTango:
            return try parseLinkedInTango(cleanText, gameId: game.id)
        case Game.Names.linkedinCrossclimb:
            return try parseLinkedInCrossclimb(cleanText, gameId: game.id)
        case Game.Names.linkedinPinpoint:
            return try parseLinkedInPinpoint(cleanText, gameId: game.id)
        case Game.Names.linkedinZip:
            return try parseLinkedInZip(cleanText, gameId: game.id)
        case Game.Names.linkedinMiniSudoku:
            return try parseLinkedInMiniSudoku(cleanText, gameId: game.id)
        case Game.Names.octordle:
            return try parseOctordle(cleanText, gameId: game.id)
        default:
            return try parseGeneric(cleanText, game: game)
        }
    }

    private func parseGeneric(_ text: String, game: Game) throws -> GameResult {
        let scorePattern = #"(\d+|X)/(\d+)"#

        guard let regex = try? NSRegularExpression(pattern: scorePattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let scoreRange = Range(match.range(at: 1), in: text),
              let maxRange = Range(match.range(at: 2), in: text) else {
            throw ParsingError.invalidFormat
        }

        let scoreString = String(text[scoreRange])
        let maxString = String(text[maxRange])

        let score = scoreString.uppercased() == "X" ? nil : Int(scoreString)
        let maxAttempts = Int(maxString) ?? 6
        let completed = scoreString.uppercased() != "X"
        
        return GameResult(
            gameId: game.id,
            gameName: game.name.lowercased(),
            date: Date(),
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            sharedText: text,
            parsedData: ["source": "manual"]
        )
    }
}

// MARK: - Parsing Error
enum ParsingError: LocalizedError {
    case invalidFormat
    case unsupportedGame
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Could not parse the game result. Please check the format."
        case .unsupportedGame:
            return "This game is not supported yet."
        }
    }
}
