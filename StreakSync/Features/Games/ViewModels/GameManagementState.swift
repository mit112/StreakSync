//
//  GameManagementState.swift
//  StreakSync
//
//  Simple state management with archive and ordering
//

import SwiftUI

@MainActor
class GameManagementState: ObservableObject {
    @Published var archivedGameIds: Set<UUID> = []
    @Published var gameOrder: [UUID] = []
    
    private let persistenceService = UserDefaultsPersistenceService()
    private let archiveKey = "archivedGames"
    private let orderKey = "gameOrder"
    
    init() {
        loadArchivedGames()
        loadGameOrder()
    }
    
    // MARK: - Archive Management
    func isArchived(_ gameId: UUID) -> Bool {
        archivedGameIds.contains(gameId)
    }
    
    func toggleArchived(for gameId: UUID) {
        if archivedGameIds.contains(gameId) {
            archivedGameIds.remove(gameId)
        } else {
            archivedGameIds.insert(gameId)
        }
        saveArchivedGames()
    }
    
    func archiveGames(_ gameIds: [UUID]) {
        archivedGameIds.formUnion(gameIds)
        saveArchivedGames()
    }
    
    func unarchiveAll() {
        archivedGameIds.removeAll()
        saveArchivedGames()
    }
    
    // MARK: - Order Management
    func moveGame(from source: IndexSet, to destination: Int) {
        gameOrder.move(fromOffsets: source, toOffset: destination)
        saveGameOrder()
    }
    
    func reorderGames(_ games: [Game]) {
        // Initialize order if empty
        if gameOrder.isEmpty {
            gameOrder = games.map { $0.id }
        } else {
            // Add any new games to the end
            let existingIds = Set(gameOrder)
            let newGames = games.filter { !existingIds.contains($0.id) }
            gameOrder.append(contentsOf: newGames.map { $0.id })
        }
    }
    
    func orderedGames(from games: [Game]) -> [Game] {
        // If no custom order, return original
        guard !gameOrder.isEmpty else { return games }
        
        // Sort by saved order
        let orderMap = Dictionary(uniqueKeysWithValues: gameOrder.enumerated().map { ($1, $0) })
        return games.sorted { game1, game2 in
            let order1 = orderMap[game1.id] ?? Int.max
            let order2 = orderMap[game2.id] ?? Int.max
            return order1 < order2
        }
    }
    
    // MARK: - Persistence
    private func loadArchivedGames() {
        if let saved = persistenceService.load([String].self, forKey: archiveKey) {
            archivedGameIds = Set(saved.compactMap { UUID(uuidString: $0) })
        }
    }
    
    private func loadGameOrder() {
        if let saved = persistenceService.load([String].self, forKey: orderKey) {
            gameOrder = saved.compactMap { UUID(uuidString: $0) }
        }
    }
    
    private func saveArchivedGames() {
        let idsToSave = archivedGameIds.map { $0.uuidString }
        try? persistenceService.save(idsToSave, forKey: archiveKey)
    }
    
    func saveGameOrder() {
        let orderToSave = gameOrder.map { $0.uuidString }
        try? persistenceService.save(orderToSave, forKey: orderKey)
    }
}
