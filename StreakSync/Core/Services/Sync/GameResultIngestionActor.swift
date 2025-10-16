//
//  GameResultIngestionActor.swift
//  StreakSync
//
//  Serializes ingestion of game results to avoid races.
//

import Foundation

actor GameResultIngestionActor {
    func ingest(_ result: GameResult, into appState: AppState) async {
        await MainActor.run {
            appState.addGameResult(result)
        }
    }
    
    func ingest(_ results: [GameResult], into appState: AppState) async {
        for result in results {
            await ingest(result, into: appState)
        }
    }
}


