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
        let parsed: GameResult
        if let parser = parserForGame(game.name.lowercased()) {
            parsed = try parser(cleanText, game.id)
        } else {
            parsed = try parseGeneric(cleanText, game: game)
        }
        // Re-date the result by the puzzle it actually is (not device receipt time)
        // so streaks survive travel across time zones / the date line (T1-3).
        return Self.applyingCanonicalPuzzleDate(to: parsed)
    }

    private func parseGeneric(_ text: String, game: Game) throws -> GameResult {
        let scorePattern = #"(\d+|X)/(\d+)"#

        guard let regex = try? NSRegularExpression(pattern: scorePattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
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

// MARK: - Canonical Puzzle Date (timezone-immune streaks)

extension GameResultParser {
    /// Known (puzzleNumber → publication date) anchors for games whose share text
    /// carries a strictly sequential daily puzzle number. Used to date a result by
    /// the puzzle it actually is rather than the device receipt time, so streaks
    /// count puzzle-days and survive travel across time zones / the date line (T1-3).
    ///
    /// Anchors captured 2026-08-07 (US/Eastern). Games absent here (Spelling Bee,
    /// Mini Crossword, Pips, LinkedIn Mini Sudoku, generic) have no usable
    /// sequential number and fall back to the receipt date.
    private static let puzzleAnchors: [String: (number: Int, year: Int, month: Int, day: Int)] = [
        Game.Names.wordle: (1875, 2026, 8, 7),
        Game.Names.connections: (1153, 2026, 8, 7),
        Game.Names.strands: (887, 2026, 8, 7),
        Game.Names.quordle: (1656, 2026, 8, 7),
        Game.Names.octordle: (1654, 2026, 8, 5),
        Game.Names.nerdle: (1658, 2026, 8, 4),
        Game.Names.linkedinQueens: (829, 2026, 8, 7),
        Game.Names.linkedinTango: (669, 2026, 8, 7),
        Game.Names.linkedinCrossclimb: (829, 2026, 8, 7),
        Game.Names.linkedinPinpoint: (829, 2026, 8, 7),
        Game.Names.linkedinZip: (508, 2026, 8, 7)
    ]

    /// Gregorian/UTC calendar used only for puzzle-date arithmetic. Anchoring at
    /// noon UTC keeps consecutive puzzles exactly 24h apart, so `Calendar.current`
    /// day-diffs (streak math) always read them as 1 day apart regardless of the
    /// device's time zone.
    private static let puzzleCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return cal
    }()

    /// Canonical publication date (noon UTC) for a parsed result derived from its
    /// puzzle number, or nil when the game has no usable sequential number.
    static func canonicalPuzzleDate(gameName: String, parsedData: [String: String]) -> Date? {
        // Weekly Quordle uses a separate numbering sequence — never anchor it.
        if parsedData["mode"] == "weekly" { return nil }

        guard let anchor = puzzleAnchors[gameName.lowercased()],
              let raw = parsedData["puzzleNumber"],
              let number = Int(raw.replacingOccurrences(of: ",", with: "")),
              number > 0 else {
            return nil
        }

        var components = DateComponents()
        components.year = anchor.year
        components.month = anchor.month
        components.day = anchor.day
        components.hour = 12
        guard let anchorDate = puzzleCalendar.date(from: components) else { return nil }
        return puzzleCalendar.date(byAdding: .day, value: number - anchor.number, to: anchorDate)
    }

    /// Replaces a parsed result's receipt date with its canonical puzzle date when
    /// one can be derived. `replacing` keeps every other field and refreshes
    /// `lastModified` to now, preserving sync conflict-resolution semantics.
    static func applyingCanonicalPuzzleDate(to result: GameResult) -> GameResult {
        guard let canonical = canonicalPuzzleDate(gameName: result.gameName, parsedData: result.parsedData) else {
            return result
        }
        // Guard against a bad anchor placing a puzzle implausibly in the future —
        // you can't have played a puzzle that releases more than ~a day ahead.
        if canonical > result.date.addingTimeInterval(36 * 3600) {
            return result
        }
        return result.replacing(date: canonical)
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
