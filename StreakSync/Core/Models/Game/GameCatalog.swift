//
//  GameCatalog.swift
//  StreakSync
//
//  Centralized game catalog management with favorites support
//

import Foundation
import SwiftUI
import OSLog

@MainActor
@Observable
final class GameCatalog {
    // MARK: - Singleton
    static let shared = GameCatalog()

    // MARK: - Properties
    private(set) var allGames: [Game] = []
    private(set) var favoriteGameIDs: Set<UUID> = []
    
    // MARK: - Persistence
    private let logger = Logger(subsystem: "com.streaksync.app", category: "GameCatalog")
    private let persistenceService = UserDefaultsPersistenceService()
    private let favoritesKey = "streaksync_favorite_games"
    
    // MARK: - Computed Properties
    
    /// Games organized by category
    var gamesByCategory: [GameCategory: [Game]] {
        Dictionary(grouping: allGames, by: { $0.category })
    }
    
    /// Popular games (marked as popular in their definition)
    var popularGames: [Game] {
        allGames.filter { $0.isPopular }
    }
    
    /// User's favorite games
    var favoriteGames: [Game] {
        allGames.filter { favoriteGameIDs.contains($0.id) }
    }
    
    /// Check if a game is favorited
    func isFavorite(_ gameId: UUID) -> Bool {
        favoriteGameIDs.contains(gameId)
    }
    
    // MARK: - Initialization
    init() {
        loadAllGames()
        loadFavorites()
    }
    
    // MARK: - Game Loading
    private func loadAllGames() {
        self.allGames = Game.allAvailableGames
        logger.info("Loaded \(self.allGames.count) games into catalog")
    }
    
    // MARK: - Favorites Management
    func toggleFavorite(_ gameId: UUID) {
        if favoriteGameIDs.contains(gameId) {
            favoriteGameIDs.remove(gameId)
            logger.info("Removed game from favorites: \(gameId)")
        } else {
            favoriteGameIDs.insert(gameId)
            logger.info("Added game to favorites: \(gameId)")
        }
        saveFavorites()
    }
    
    func addFavorite(_ gameId: UUID) {
        favoriteGameIDs.insert(gameId)
        saveFavorites()
    }
    
    func removeFavorite(_ gameId: UUID) {
        favoriteGameIDs.remove(gameId)
        saveFavorites()
    }
    
    // MARK: - Persistence
    private func loadFavorites() {
        logger.info("Loading favorite games...")
        
        if let savedIDs = persistenceService.load([String].self, forKey: favoritesKey) {
            favoriteGameIDs = Set(savedIDs.compactMap { UUID(uuidString: $0) })
            logger.info("Loaded \(self.favoriteGameIDs.count) favorite games")
        } else {
            logger.info("No saved favorites found - starting with empty favorites")
            // Don't default to any favorites - let user choose
            favoriteGameIDs = Set()
        }
    }
    
    private func saveFavorites() {
        let idsToSave = favoriteGameIDs.map { $0.uuidString }
        do {
            try persistenceService.save(idsToSave, forKey: favoritesKey)
            logger.info("✅ Saved \(idsToSave.count) favorite games")
        } catch {
            logger.error("❌ Failed to save favorites: \(error)")
        }
    }
    
    // MARK: - Game Management (Future)
    
    /// Add a new game to the catalog (for future custom games)
    func addCustomGame(_ game: Game) {
        guard !allGames.contains(where: { $0.id == game.id }) else {
            logger.warning("Attempted to add duplicate game: \(game.id)")
            return
        }
        allGames.append(game)
        logger.info("Added custom game: \(game.displayName)")
    }
    
    /// Remove a custom game (only custom games can be removed)
    func removeCustomGame(_ gameId: UUID) {
        guard let game = allGames.first(where: { $0.id == gameId }),
              game.isCustom else {
            logger.warning("Cannot remove non-custom game: \(gameId)")
            return
        }
        
        allGames.removeAll { $0.id == gameId }
        favoriteGameIDs.remove(gameId)
        saveFavorites()
        logger.info("Removed custom game: \(game.displayName)")
    }
}
