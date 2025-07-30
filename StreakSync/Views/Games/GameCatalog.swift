//
//  GameCatalog.swift
//  StreakSync
//
//  Centralized game catalog management with favorites support
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class GameCatalog {
    // MARK: - Properties
    private(set) var allGames: [Game] = []
    private(set) var favoriteGameIDs: Set<UUID> = []
    
    // MARK: - Persistence Keys
    private let favoritesKey = "favoriteGameIDs"
    
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
        // Start with the existing popular games to maintain compatibility
//        var games = Game.popularGames
        self.allGames = Game.allAvailableGames
        // Add any additional games here in the future
        // For example:
        // games.append(contentsOf: GameRegistry.additionalGames)
    }
    
    // MARK: - Favorites Management
    func toggleFavorite(_ gameId: UUID) {
        if favoriteGameIDs.contains(gameId) {
            favoriteGameIDs.remove(gameId)
        } else {
            favoriteGameIDs.insert(gameId)
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
        if let savedIDs = UserDefaults.standard.stringArray(forKey: favoritesKey) {
            favoriteGameIDs = Set(savedIDs.compactMap { UUID(uuidString: $0) })
            
            // If no favorites saved, default to showing all current games as favorites
            if favoriteGameIDs.isEmpty {
                favoriteGameIDs = Set(Game.popularGames.map { $0.id })
            }
        } else {
            // First time: all existing games are favorites by default
            favoriteGameIDs = Set(Game.popularGames.map { $0.id })
            saveFavorites()
        }
    }
    
    private func saveFavorites() {
        let idStrings = favoriteGameIDs.map { $0.uuidString }
        UserDefaults.standard.set(idStrings, forKey: favoritesKey)
    }
    
    // MARK: - Game Management (Future)
    
    /// Add a new game to the catalog (for future custom games)
    func addCustomGame(_ game: Game) {
        guard !allGames.contains(where: { $0.id == game.id }) else { return }
        allGames.append(game)
        // Could persist custom games separately
    }
    
    /// Remove a custom game (only custom games can be removed)
    func removeCustomGame(_ gameId: UUID) {
        guard let game = allGames.first(where: { $0.id == gameId }),
              game.isCustom else { return }
        
        allGames.removeAll { $0.id == gameId }
        favoriteGameIDs.remove(gameId)
        saveFavorites()
    }
}
