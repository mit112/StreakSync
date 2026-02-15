//
//  GameResultParser+NYT.swift
//  StreakSync
//
//  NYT game parsers: Wordle, Connections, Spelling Bee, Mini Crossword, Strands
//

import Foundation

extension GameResultParser {

    // MARK: - Wordle Parser
    func parseWordle(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "Wordle 1,492 3/6" or "Wordle 1492 X/6"
        let pattern = #"Wordle\s+(\d+(?:,\d+)*)\s+([X1-6])/6"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text),
              let scoreRange = Range(match.range(at: 2), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let puzzleNumber = String(text[puzzleRange]).replacingOccurrences(of: ",", with: "")
        let scoreString = String(text[scoreRange])
        
        let score = scoreString == "X" ? nil : Int(scoreString)
        let completed = scoreString != "X"
        
        return GameResult(
            gameId: gameId,
            gameName: "wordle",
            date: Date(),
            score: score,
            maxAttempts: 6,
            completed: completed,
            sharedText: text,
            parsedData: ["puzzleNumber": puzzleNumber]
        )
    }
    

    // MARK: - NYT Connections Parser
    func parseConnections(_ text: String, gameId: UUID) throws -> GameResult {
        // Check if this looks like a Connections result
        guard text.contains("Connections") && text.contains("Puzzle #") else {
            throw ParsingError.invalidFormat
        }
        
        // Extract puzzle number using a simple approach
        let puzzleNumberPattern = #"Puzzle #(\d+)"#
        guard let puzzleRegex = try? NSRegularExpression(pattern: puzzleNumberPattern, options: .caseInsensitive),
              let puzzleMatch = puzzleRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(puzzleMatch.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let puzzleNumber = String(text[puzzleRange])
        
        // Extract emoji grid - split by lines and find emoji-only lines
        let lines = text.components(separatedBy: .newlines)
        var emojiRows: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Check if line contains only emoji squares (4 emojis)
            if trimmedLine.count == 4 && 
               trimmedLine.allSatisfy({ "🟩🟨🟦🟪".contains($0) }) {
                emojiRows.append(trimmedLine)
            }
        }
        
        // Parse the emoji grid to extract game statistics
        let gameStats = parseConnectionsEmojiGrid(emojiRows.joined(separator: " "))
        
        return GameResult(
            gameId: gameId,
            gameName: "connections",
            date: Date(),
            score: gameStats.solvedCategories, // Always include score (0-4)
            maxAttempts: 4, // 4 categories total
            completed: gameStats.completed, // Only true if all 4 categories solved
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "totalGuesses": "\(gameStats.totalGuesses)",
                "solvedCategories": "\(gameStats.solvedCategories)",
                "strikes": "\(gameStats.strikes)",
                "emojiGrid": emojiRows.joined(separator: " ")
            ]
        )
    }
    
    // MARK: - Connections Emoji Grid Parser Helper
    func parseConnectionsEmojiGrid(_ emojiGrid: String) -> (totalGuesses: Int, solvedCategories: Int, strikes: Int, completed: Bool) {
        // Split by spaces to get individual emoji rows
        let emojiRows = emojiGrid.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .filter { $0.contains("🟩") || $0.contains("🟨") || $0.contains("🟦") || $0.contains("🟪") }
        
        var solvedCategories = 0
        var strikes = 0
        
        for row in emojiRows {
            // Check if this row has 4 identical emojis (solved category)
            let emojis = Array(row)
            if emojis.count == 4 {
                // Check if all 4 emojis are the same
                let firstEmoji = emojis[0]
                let allSame = emojis.allSatisfy { $0 == firstEmoji }
                
                if allSame {
                    solvedCategories += 1
                } else {
                    strikes += 1
                }
            } else {
                // Invalid row format, count as strike
                strikes += 1
            }
        }
        
        let totalGuesses = emojiRows.count
        let completed = solvedCategories == 4
        
        return (totalGuesses: totalGuesses, solvedCategories: solvedCategories, strikes: strikes, completed: completed)
    }
    

    // MARK: - NYT Spelling Bee Parser
    func parseSpellingBee(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "Spelling Bee\nScore: 150\nWords: 25\nRank: Genius"
        let pattern = #"Spelling Bee[\s\S]*?Score:\s*(\d+)[\s\S]*?Words:\s*(\d+)[\s\S]*?Rank:\s*([A-Za-z\s]+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let scoreRange = Range(match.range(at: 1), in: text),
              let wordsRange = Range(match.range(at: 2), in: text),
              let rankRange = Range(match.range(at: 3), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let scoreString = String(text[scoreRange])
        let wordsString = String(text[wordsRange])
        let rankString = String(text[rankRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let score = Int(scoreString) ?? 0
        let _ = Int(wordsString) ?? 0 // wordsFound - not used in current implementation
        
        // Determine completion based on rank (Genius and above are considered "completed")
        let completed = rankString.lowercased().contains("genius") || 
                       rankString.lowercased().contains("queen bee") ||
                       rankString.lowercased().contains("amazing")
        
        return GameResult(
            gameId: gameId,
            gameName: "spellingbee",
            date: Date(),
            score: score,
            maxAttempts: 1000, // High number since Spelling Bee has no fixed max
            completed: completed,
            sharedText: text,
            parsedData: [
                "score": scoreString,
                "wordsFound": wordsString,
                "rank": rankString
            ]
        )
    }
    

    // MARK: - NYT Mini Crossword Parser
    func parseMiniCrossword(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern: "Mini Crossword\nCompleted in 2:30"
        let pattern = #"Mini Crossword[\s\S]*?Completed in (\d+:\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let timeRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        
        let completionTime = String(text[timeRange])
        
        // Parse completion time (MM:SS format)
        let timeComponents = completionTime.split(separator: ":")
        let totalSeconds: Int
        if timeComponents.count == 2,
           let minutes = Int(timeComponents[0]),
           let seconds = Int(timeComponents[1]) {
            totalSeconds = minutes * 60 + seconds
        } else {
            totalSeconds = 0
        }
        
        // Mini Crossword is always completed if we can parse the time
        return GameResult(
            gameId: gameId,
            gameName: "minicrossword",
            date: Date(),
            score: totalSeconds, // Use completion time as score (lower is better)
            maxAttempts: 600, // 10 minutes max (reasonable limit)
            completed: true,
            sharedText: text,
            parsedData: [
                "completionTime": completionTime,
                "totalSeconds": "\(totalSeconds)"
            ]
        )
    }
    

    // MARK: - NYT Strands Parser
    func parseStrands(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern for Strands results - actual shared format
        // Format: "Strands #580\n\"Bring it home\"\n💡🔵🔵💡\n🔵🟡🔵🔵\n🔵"
        let pattern = #"Strands\s+#(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            throw ParsingError.invalidFormat
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        let puzzleNumber = String(text[puzzleRange])
        
        // Extract theme (optional)
        var theme = ""
        let themePattern = #""([^"]+)""#
        if let themeRegex = try? NSRegularExpression(pattern: themePattern, options: .caseInsensitive),
           let themeMatch = themeRegex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
           themeMatch.range(at: 1).location != NSNotFound,
           let themeRange = Range(themeMatch.range(at: 1), in: text) {
            theme = String(text[themeRange])
        }
        
        // Count hint emojis (💡) to determine hint count
        let hintCount = text.components(separatedBy: "💡").count - 1
        
        // For Strands, score is the number of hints used (lower is better)
        // Perfect score = 0 hints, Hinted = 1+ hints
        let score = hintCount
        
        return GameResult(
            gameId: gameId,
            gameName: "strands",
            date: Date(),
            score: score,
            maxAttempts: 10, // Reasonable upper limit for hints
            completed: true, // Strands is always completed (no failure state)
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "hintCount": "\(hintCount)",
                "theme": theme,
                "gameType": "word_puzzle",
                "displayScore": hintCount == 0 ? "Perfect" : "\(hintCount) hints"
            ]
        )
    }
}
