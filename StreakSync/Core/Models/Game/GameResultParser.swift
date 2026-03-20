//
//  GameResultParser.swift
//  StreakSync
//
//  Game result parser — routes to per-category extensions
//

import Foundation

// MARK: - Game Result Parser
struct GameResultParser {
    // swiftlint:disable:next cyclomatic_complexity
    private func parserForGame(
        _ name: String
    ) -> ((String, UUID) throws -> GameResult)? {
        switch name {
        case Game.Names.wordle: return parseWordle
        case Game.Names.quordle: return parseQuordle
        case Game.Names.nerdle: return parseNerdle
        case Game.Names.pips: return parsePips
        case Game.Names.connections: return parseConnections
        case Game.Names.spellingBee: return parseSpellingBee
        case Game.Names.miniCrossword: return parseMiniCrossword
        case Game.Names.strands: return parseStrands
        case Game.Names.linkedinQueens: return parseLinkedInQueens
        case Game.Names.linkedinTango: return parseLinkedInTango
        case Game.Names.linkedinCrossclimb: return parseLinkedInCrossclimb
        case Game.Names.linkedinPinpoint: return parseLinkedInPinpoint
        case Game.Names.linkedinZip: return parseLinkedInZip
        case Game.Names.linkedinMiniSudoku: return parseLinkedInMiniSudoku
        case Game.Names.octordle: return parseOctordle
        default: return nil
        }
    }

    func parse(_ text: String, for game: Game) throws -> GameResult {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parser = parserForGame(game.name.lowercased()) {
            return try parser(cleanText, game.id)
        }
        return try parseGeneric(cleanText, game: game)
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
