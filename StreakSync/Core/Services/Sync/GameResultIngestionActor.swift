//
//  GameResultIngestionActor.swift
//  StreakSync
//
//  Serializes ingestion of game results to avoid races.
//

import Foundation

actor GameResultIngestionActor {
    /// Ingests a single result and returns true if it was actually added (not duplicate/invalid).
    func ingest(_ result: GameResult, into appState: AppState) async -> Bool {
        let added: Bool = await MainActor.run {
            appState.addGameResult(result)
        }
        return added
    }
    
    /// Ingests multiple results; returns the number actually added.
    @discardableResult
    func ingest(_ results: [GameResult], into appState: AppState) async -> Int {
        var addedCount = 0
        for result in results {
            if await ingest(result, into: appState) {
                addedCount += 1
            }
        }
        return addedCount
    }
}


