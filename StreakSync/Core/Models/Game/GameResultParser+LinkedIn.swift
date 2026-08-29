//
//  GameResultParser+LinkedIn.swift
//  StreakSync
//
//  LinkedIn game parsers: Queens, Tango, Crossclimb, Pinpoint, Zip, Mini Sudoku
//

import Foundation

extension GameResultParser {
    // MARK: - LinkedIn Games Parsers
    
    // MARK: - LinkedIn Queens Parser
    func parseLinkedInQueens(_ text: String, gameId: UUID) throws -> GameResult {
        // "Queens #522" or "Queens 522"; the time (if present) is captured from
        // the same match onward rather than via a separate whole-text search, so
        // a combined multi-game post (e.g. Tango/Queens/Zip all in one comment)
        // can't steal an earlier game's time.
        let pattern = #"Queens\s+#?(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }

        let puzzleNumber = String(text[puzzleRange])
        var timeString: String?
        if match.range(at: 2).location != NSNotFound,
           let timeRange = Range(match.range(at: 2), in: text) {
            timeString = String(text[timeRange])
        }

        // For Queens, score is the actual time in seconds. If the time didn't
        // parse, don't fabricate a 0-second solve — under LeaderboardScoring's
        // lowerTimeSeconds bucketing that would rank as the best possible score.
        // Record the puzzle as played/completed with an honest nil score instead.
        var score: Int?
        if let time = timeString {
            let timeComponents = time.components(separatedBy: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                score = minutes * 60 + seconds
            }
        }

        return GameResult(
            gameId: gameId,
            gameName: "linkedinqueens",
            date: Date(),
            score: score,
            maxAttempts: 0, // Queens doesn't have attempts/backtracks
            completed: true,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "gameType": "logic_puzzle",
                "displayScore": timeString ?? "Completed"
            ]
        )
    }
    
    // MARK: - LinkedIn Tango Parser
    func parseLinkedInTango(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern for Tango results with time
        // Format: "Tango #362\n1:10 🌗\nlnkd.in/tango."
        let pattern = #"Tango\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) else {
            throw ParsingError.invalidFormat
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        let puzzleNumber = String(text[puzzleRange])
        
        // Extract time
        var timeString: String?
        if match.range(at: 2).location != NSNotFound {
            if let timeRange = Range(match.range(at: 2), in: text) {
                timeString = String(text[timeRange])
            }
        }
        
        // For Tango, score is the actual time in seconds. If the time didn't
        // parse, don't fabricate a 0-second solve (see Queens parser above for
        // why); record the puzzle as completed with an honest nil score.
        var score: Int?
        if let time = timeString {
            let timeComponents = time.components(separatedBy: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                score = minutes * 60 + seconds
            }
        }

        return GameResult(
            gameId: gameId,
            gameName: "linkedintango",
            date: Date(),
            score: score,
            maxAttempts: 0, // Tango doesn't have attempts/backtracks
            completed: true,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "gameType": "logic_puzzle",
                "displayScore": timeString ?? "Completed"
            ]
        )
    }
    
    // MARK: - LinkedIn Crossclimb Parser
    func parseLinkedInCrossclimb(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern for Crossclimb results with time
        // Format: "Crossclimb #522\n2:08 🪜\n🏅 I'm on a 94-day win streak!\nlnkd.in/crossclimb."
        let pattern = #"Crossclimb\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) else {
            throw ParsingError.invalidFormat
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        let puzzleNumber = String(text[puzzleRange])
        
        // Extract time
        var timeString: String?
        if match.range(at: 2).location != NSNotFound {
            if let timeRange = Range(match.range(at: 2), in: text) {
                timeString = String(text[timeRange])
            }
        }
        
        // For Crossclimb, score is the actual time in seconds. If the time
        // didn't parse, don't fabricate a 0-second solve (see Queens parser
        // above for why); record the puzzle as completed with an honest nil score.
        var score: Int?
        if let time = timeString {
            let timeComponents = time.components(separatedBy: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                score = minutes * 60 + seconds
            }
        }

        return GameResult(
            gameId: gameId,
            gameName: "linkedincrossclimb",
            date: Date(),
            score: score,
            maxAttempts: 0, // Crossclimb doesn't have attempts/backtracks
            completed: true,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "gameType": "word_association",
                "displayScore": timeString ?? "Completed"
            ]
        )
    }
    
    // MARK: - LinkedIn Pinpoint Parser
    func parseLinkedInPinpoint(_ text: String, gameId: UUID) throws -> GameResult {
        // Two share formats:
        // Emoji grid: "Pinpoint #542\n🤔 📌 ⬜ ⬜ ⬜ (2/5)\n🏅 …\nlnkd.in/pinpoint."
        // Original:   "Pinpoint #522 | 5 guesses\n1️⃣ | 1% match\n…\n5️⃣ | 100% match 📌"
        if let result = try parsePinpointEmojiFormat(text, gameId: gameId) {
            return result
        }
        return try parsePinpointOriginalFormat(text, gameId: gameId)
    }

    /// Emoji-grid format. Returns nil when the text isn't in this format so the
    /// caller can fall back; throws only when the grid matched but is malformed.
    private func parsePinpointEmojiFormat(_ text: String, gameId: UUID) throws -> GameResult? {
        // Accept any emoji sequence before the parenthesized score, e.g.
        // "🤔 🤔 🤔 🤔 📌 (5/5)" or "🤔 📌 ⬜ ⬜ ⬜ (2/5)".
        let pattern = #"Pinpoint\s+#(\d+)[\s\S]*?(?:[🤔📌⬜⬛🟩🟨🟧🟦🟪🟫⚫⚪\s]+)?\((\d+)/(\d+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                  in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)
              ) else {
            return nil
        }
        guard let puzzleRange = Range(match.range(at: 1), in: text),
              let guessRange = Range(match.range(at: 2), in: text),
              let maxRange = Range(match.range(at: 3), in: text) else {
            throw ParsingError.invalidFormat
        }
        let puzzleNumber = String(text[puzzleRange])
        let guessCount = Int(String(text[guessRange])) ?? 0
        let maxAttempts = Int(String(text[maxRange])) ?? 5

        // The 📌 has to sit in *this* puzzle's own row. Scanning the whole share let a
        // pin from another game in a combined daily post mark this puzzle solved.
        let row = Range(match.range, in: text).map { String(text[$0]) } ?? text
        let isCompleted = row.contains("📌")

        return GameResult(
            gameId: gameId,
            gameName: "linkedinpinpoint",
            date: Date(),
            score: pinpointScore(guessCount: guessCount, maxAttempts: maxAttempts),
            maxAttempts: maxAttempts,
            completed: isCompleted,
            sharedText: text,
            parsedData: pinpointParsedData(
                puzzleNumber: puzzleNumber, guessCount: guessCount,
                isCompleted: isCompleted, shareFormat: "emoji_based"
            )
        )
    }

    /// Original percent-match format.
    private func parsePinpointOriginalFormat(_ text: String, gameId: UUID) throws -> GameResult {
        // The second "guesses" capture is wrapped together with its own lazy scan
        // (like the first) rather than left as a separate trailing optional group —
        // otherwise the regex engine is satisfied by the empty match immediately
        // after the first optional group and never searches further for it (same
        // dead-capture-group defect as the Zip backtrack pattern above).
        let pattern = #"Pinpoint\s+#(\d+)(?:\s*\|\s*(\d+)\s+guesses)?(?:[\s\S]*?(\d+)\s+guesses)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                  in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)
              ),
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        let puzzleNumber = String(text[puzzleRange])
        let maxAttempts = 5 // Pinpoint allows up to 5 guesses

        // Read only this puzzle's slice of the share. Players post their whole daily
        // set in one comment, and Crossclimb's "Fill order: 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣" row
        // alone would otherwise be counted as Pinpoint guesses — and two such rows
        // sum past maxAttempts and trip GameResult's scoring assert.
        let segment = pinpointSegment(of: text, matching: match.range)

        var guessCount = 0
        if let range = Range(match.range(at: 2), in: text) ?? Range(match.range(at: 3), in: text) {
            guessCount = Int(String(text[range])) ?? 0
        }
        if guessCount == 0 {
            guessCount = pinpointKeycapCount(in: segment)
        }

        let isCompleted = segment.contains("100% match") || segment.contains("📌")

        return GameResult(
            gameId: gameId,
            gameName: "linkedinpinpoint",
            date: Date(),
            score: pinpointScore(guessCount: guessCount, maxAttempts: maxAttempts),
            maxAttempts: maxAttempts,
            completed: isCompleted,
            sharedText: text,
            parsedData: pinpointParsedData(
                puzzleNumber: puzzleNumber, guessCount: guessCount,
                isCompleted: isCompleted, shareFormat: "original"
            )
        )
    }

    /// The slice of a combined share belonging to this puzzle: from the matched
    /// "Pinpoint #N" header up to its own `lnkd.in/pinpoint` footer.
    private func pinpointSegment(of text: String, matching matchRange: NSRange) -> String {
        guard let range = Range(matchRange, in: text) else { return text }
        let rest = text[range.lowerBound...]
        guard let footer = rest.range(of: "lnkd.in/pinpoint", options: .caseInsensitive) else {
            return String(rest)
        }
        return String(rest[..<footer.lowerBound])
    }

    private func pinpointKeycapCount(in segment: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+️⃣)"#, options: .caseInsensitive) else {
            return 0
        }
        return regex.numberOfMatches(
            in: segment, options: [], range: NSRange(location: 0, length: segment.utf16.count)
        )
    }

    /// Never fabricate a guess count. 1 is the *best possible* Pinpoint score, so the
    /// old `guessCount > 0 ? guessCount : 1` claimed a flawless solve for a puzzle
    /// that may never have been solved — and then won `computePersonalBests`'
    /// `min(by: score)`. An unreadable count records nil, the same convention as
    /// Wordle's "X/6" and Queens' unparseable time. The upper bound also keeps the
    /// value inside `GameResult`'s `.lowerGuesses` assert if a stray keycap row
    /// inflates the count.
    private func pinpointScore(guessCount: Int, maxAttempts: Int) -> Int? {
        (guessCount >= 1 && guessCount <= maxAttempts) ? guessCount : nil
    }

    private func pinpointParsedData(
        puzzleNumber: String, guessCount: Int, isCompleted: Bool, shareFormat: String
    ) -> [String: String] {
        [
            "puzzleNumber": puzzleNumber,
            // Empty rather than "0": GameResultDisplay.pinpointDisplayScore keys off a
            // non-empty guessCount and would otherwise render a literal "0 guesses".
            "guessCount": guessCount > 0 ? "\(guessCount)" : "",
            "gameType": "word_association",
            // The Share Extension sheet shows this string verbatim; "Completed" for an
            // unsolved puzzle told the user the opposite of the truth.
            "displayScore": guessCount > 0
                ? (guessCount == 1 ? "1 guess" : "\(guessCount) guesses")
                : (isCompleted ? "Solved" : "Did not solve"),
            "shareFormat": shareFormat
        ]
    }
    
    // MARK: - LinkedIn Zip Parser
    func parseLinkedInZip(_ text: String, gameId: UUID) throws -> GameResult {
        // Pattern for Zip results with time and optional backtrack info
        // Format 1: "Zip #201 | 0:23 🏁\nWith 1 backtrack 🛑\nlnkd.in/zip."
        // Format 2: "Zip #201\n0:37 🏁\nlnkd.in/zip."
        // The backtrack capture is wrapped together with its own lazy scan (like
        // the time group) rather than left as a separate trailing optional group —
        // otherwise the regex engine is satisfied by the empty match immediately
        // after the time group and never actually searches for "With N backtrack".
        let pattern = #"Zip\s+#(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?(?:[\s\S]*?With\s+(\d+)\s+backtrack)?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) else {
            throw ParsingError.invalidFormat
        }
        
        // Extract puzzle number
        guard match.range(at: 1).location != NSNotFound,
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }
        let puzzleNumber = String(text[puzzleRange])
        
        // Extract time (now in group 2)
        var timeString: String?
        if match.range(at: 2).location != NSNotFound {
            if let timeRange = Range(match.range(at: 2), in: text) {
                timeString = String(text[timeRange])
            }
        }
        
        // Extract backtrack count (now in group 3)
        var backtrackCount = "0"
        if match.range(at: 3).location != NSNotFound {
            if let backtrackRange = Range(match.range(at: 3), in: text) {
                backtrackCount = String(text[backtrackRange])
            }
        }
        
        // For Zip, score is the actual time in seconds. If the time didn't
        // parse, don't fabricate a 0-second solve (see Queens parser above for
        // why); record the puzzle as completed with an honest nil score.
        var score: Int?
        if let time = timeString {
            let timeComponents = time.components(separatedBy: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                score = minutes * 60 + seconds
            }
        }

        return GameResult(
            gameId: gameId,
            gameName: "linkedinzip",
            date: Date(),
            score: score,
            maxAttempts: Int(backtrackCount) ?? 0, // Use backtrack count as maxAttempts
            completed: true,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "time": timeString ?? "",
                "backtrackCount": backtrackCount,
                "gameType": "connectivity_puzzle",
                "displayScore": timeString ?? "Completed"
            ]
        )
    }
    
    // MARK: - LinkedIn Mini Sudoku Parser
    func parseLinkedInMiniSudoku(_ text: String, gameId: UUID) throws -> GameResult {
        let searchRange = NSRange(text.startIndex..., in: text)

        // Numbered: "Mini Sudoku #142 | …" or legacy "Mini Sudoku puzzle #45 completed"
        // The time (if present) is captured from the same match onward rather than
        // via a separate whole-text search, so a combined multi-game post can't
        // steal another game's time (same fix as the Queens parser above).
        let numberedPattern = #"Mini Sudoku(?:\s+#|\s+puzzle\s+#)(\d+)(?:[\s\S]*?(\d{1,2}:\d{2}))?"#
        if let numberedRegex = try? NSRegularExpression(pattern: numberedPattern, options: .caseInsensitive),
           let match = numberedRegex.firstMatch(in: text, options: [], range: searchRange),
           let puzzleRange = Range(match.range(at: 1), in: text) {
            var embeddedTimeString: String?
            if match.range(at: 2).location != NSNotFound,
               let timeRange = Range(match.range(at: 2), in: text) {
                embeddedTimeString = String(text[timeRange])
            }
            return makeLinkedInMiniSudokuResult(
                gameId: gameId,
                text: text,
                puzzleIdentifier: String(text[puzzleRange]),
                pointsScore: linkedInFirstCapture(#"Score:\s*(\d+)"#, in: text),
                timeString: embeddedTimeString,
                shareFormat: "numbered"
            )
        }

        // Dated block: "Mini Sudoku - May 19, 2026\nScore: 95\nTime: 1:23"
        let datedPattern = #"Mini Sudoku\s*-\s*([^\n]+)"#
        guard let datedRegex = try? NSRegularExpression(pattern: datedPattern, options: .caseInsensitive),
              let datedMatch = datedRegex.firstMatch(in: text, options: [], range: searchRange),
              let dateRange = Range(datedMatch.range(at: 1), in: text) else {
            throw ParsingError.invalidFormat
        }

        let puzzleDate = String(text[dateRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let pointsScore = linkedInFirstCapture(#"Score:\s*(\d+)"#, in: text)
        let timeString = linkedInFirstCapture(#"Time:\s*(\d{1,2}:\d{2})"#, in: text)

        guard pointsScore != nil || timeString != nil else {
            throw ParsingError.invalidFormat
        }

        return makeLinkedInMiniSudokuResult(
            gameId: gameId,
            text: text,
            puzzleIdentifier: puzzleDate,
            pointsScore: pointsScore,
            timeString: timeString,
            shareFormat: "dated"
        )
    }

    private func makeLinkedInMiniSudokuResult(
        gameId: UUID,
        text: String,
        puzzleIdentifier: String,
        pointsScore: String?,
        timeString: String?,
        shareFormat: String
    ) -> GameResult {
        var parsedData: [String: String] = [
            "puzzleNumber": puzzleIdentifier,
            "gameType": "sudoku",
            "shareFormat": shareFormat
        ]
        if let pointsScore {
            parsedData["pointsScore"] = pointsScore
        }
        if let timeString {
            parsedData["time"] = timeString
            parsedData["displayScore"] = timeString
        } else if let pointsScore {
            parsedData["displayScore"] = pointsScore
        }

        // For Mini Sudoku, score is the actual time in seconds. If the time didn't
        // parse, don't fabricate a 0-second solve (see Queens parser above for
        // why); record the puzzle as completed with an honest nil score instead.
        var score: Int?
        if let time = timeString {
            let timeComponents = time.components(separatedBy: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                score = minutes * 60 + seconds
            }
        }

        return GameResult(
            gameId: gameId,
            gameName: "linkedinminisudoku",
            date: Date(),
            score: score,
            maxAttempts: 600, // Matches Pips/Mini Crossword's time-based ceiling
            completed: true,
            sharedText: text,
            parsedData: parsedData
        )
    }

    private func linkedInFirstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
}
