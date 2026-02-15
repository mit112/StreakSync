//
//  AppState+DuplicateDetection.swift
//  StreakSync
//
//  Duplicate detection logic extracted from AppState
//

import Foundation

extension AppState {

    // MARK: - Duplicate Detection

    internal func isDuplicateResult(_ result: GameResult) -> Bool {
        let puzzleNumber = result.parsedData["puzzleNumber"] ?? ""

        // Clean puzzle number (remove commas and spaces)
        let cleanPuzzleNumber = puzzleNumber
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

 logger.debug("Checking duplicate for \(result.gameName) puzzle: \(cleanPuzzleNumber)")
 logger.debug("Current results count: \(self.recentResults.count)")
 logger.debug("🆔 Result ID: \(result.id)")
 logger.debug("Result date: \(result.date)")

        // Log existing results for debugging
        for existingResult in self.recentResults.prefix(5) {
            let existingPuzzle = existingResult.parsedData["puzzleNumber"] ?? "unknown"
 logger.debug("Existing: \(existingResult.gameName) #\(existingPuzzle) on \(existingResult.date)")
        }

        // Build cache if needed - ensure it's always up to date
        if self.gameResultsCache.isEmpty {
 logger.debug("Building results cache (was empty)")
            buildResultsCache()
        } else {
            // Double-check that the cache is current
            let expectedCacheSize = self.recentResults.filter { result in
                let puzzleNumber = result.parsedData["puzzleNumber"] ?? ""
                let cleanPuzzleNumber = puzzleNumber
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: " ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown"
            }.count

            let actualCacheSize = self.gameResultsCache.values.flatMap { $0 }.count
            if expectedCacheSize != actualCacheSize {
 logger.debug("Rebuilding results cache (size mismatch: expected \(expectedCacheSize), actual \(actualCacheSize))")
                buildResultsCache()
            }
        }

        // Method 1: Check exact ID match
        if self.recentResults.contains(where: { $0.id == result.id }) {
 logger.debug("Duplicate detected: Exact ID match")
            return true
        }

        // Method 2: Check puzzle number for games that have them
        if !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown" {
            // Special handling for Pips - check puzzle number + difficulty combination
            if result.gameName.lowercased() == "pips" {
                let difficulty = result.parsedData["difficulty"] ?? ""
                let puzzleDifficultyKey = "\(cleanPuzzleNumber)-\(difficulty)"

                if let cachedPuzzles = self.gameResultsCache[result.gameId],
                   cachedPuzzles.contains(puzzleDifficultyKey) {
 logger.debug("Duplicate detected: Puzzle #\(cleanPuzzleNumber) \(difficulty) already exists for \(result.gameName)")
                    return true
                }
            } else {
                // Standard puzzle number check for other games
                if let cachedPuzzles = self.gameResultsCache[result.gameId],
                   cachedPuzzles.contains(cleanPuzzleNumber) {
 logger.debug("Duplicate detected: Puzzle #\(cleanPuzzleNumber) already exists for \(result.gameName)")
                    return true
                }
            }
        }

        // Method 3: For games without puzzle numbers, check same day
        if cleanPuzzleNumber.isEmpty || cleanPuzzleNumber == "unknown" {
            let calendar = Calendar.current
            let resultDay = calendar.startOfDay(for: result.date)

            let existingOnSameDay = self.recentResults.first { existingResult in
                guard existingResult.gameId == result.gameId else { return false }

                let existingDay = calendar.startOfDay(for: existingResult.date)
                return existingDay == resultDay
            }

            if existingOnSameDay != nil {
 logger.debug("Same-day duplicate detected for \(result.gameName)")
                return true
            }
        }

 logger.debug("No duplicate found - result is unique")
        return false
    }

    internal func buildResultsCache() {
        self.gameResultsCache.removeAll()

        for result in self.recentResults {
            let puzzleNumber = result.parsedData["puzzleNumber"] ?? ""
            let cleanPuzzleNumber = puzzleNumber
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown" {
                if self.gameResultsCache[result.gameId] == nil {
                    self.gameResultsCache[result.gameId] = Set<String>()
                }

                // Special handling for Pips - store puzzle number + difficulty combination
                if result.gameName.lowercased() == "pips" {
                    let difficulty = result.parsedData["difficulty"] ?? ""
                    let puzzleDifficultyKey = "\(cleanPuzzleNumber)-\(difficulty)"
                    self.gameResultsCache[result.gameId]?.insert(puzzleDifficultyKey)
                } else {
                    // Standard puzzle number for other games
                    self.gameResultsCache[result.gameId]?.insert(cleanPuzzleNumber)
                }
            }
        }

 logger.debug("Built results cache with \(self.gameResultsCache.count) games")
    }

    /// Updates the duplicate-prevention cache after a single result insertion.
    /// Called by `addGameResult` to keep the cache in sync without a full rebuild.
    internal func updateResultsCache(for result: GameResult) {
        let puzzleNumber = result.parsedData["puzzleNumber"] ?? ""
        let cleanPuzzleNumber = puzzleNumber
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanPuzzleNumber.isEmpty && cleanPuzzleNumber != "unknown" {
            if self.gameResultsCache[result.gameId] == nil {
                self.gameResultsCache[result.gameId] = Set<String>()
            }

            if result.gameName.lowercased() == "pips" {
                let difficulty = result.parsedData["difficulty"] ?? ""
                let puzzleDifficultyKey = "\(cleanPuzzleNumber)-\(difficulty)"
                self.gameResultsCache[result.gameId]?.insert(puzzleDifficultyKey)
            } else {
                self.gameResultsCache[result.gameId]?.insert(cleanPuzzleNumber)
            }
        }
    }
}
