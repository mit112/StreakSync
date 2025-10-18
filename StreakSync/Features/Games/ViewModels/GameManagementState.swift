//
//  GameManagementState.swift
//  StreakSync
//
//  Simple state management with archive and ordering
//

/*
 * GAMEMANAGEMENTSTATE - GAME ORGANIZATION AND CUSTOMIZATION MANAGER
 * 
 * WHAT THIS FILE DOES:
 * This file manages the user's game organization preferences, including which games
 * are archived and the custom order of games. It's like a "game organizer" that
 * remembers how users want their games arranged and which ones they want to hide.
 * Think of it as the "game customization system" that allows users to personalize
 * their game list by archiving games they don't play and reordering games to their
 * preference.
 * 
 * WHY IT EXISTS:
 * Users need control over their game list - they want to hide games they don't play
 * and arrange games in their preferred order. This state manager provides a simple
 * way to manage these preferences and persist them across app sessions. It keeps
 * the game list clean and organized according to user preferences.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides essential user customization features
 * - Manages game archiving to hide games users don't play
 * - Handles custom game ordering for personalized organization
 * - Persists user preferences across app sessions
 * - Provides simple, intuitive game management controls
 * - Enhances user experience by allowing personalization
 * - Keeps the game list clean and organized
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For @Published properties and reactive updates
 * - UserDefaultsPersistenceService: For persisting user preferences
 * - UUID: For unique game identification
 * - Set and Array: For managing collections of game IDs
 * 
 * WHAT REFERENCES IT:
 * - Game management views: Use this for archiving and ordering functionality
 * - Dashboard views: Use this to filter and order games
 * - Settings views: Use this for game management controls
 * - Various game components: Use this for game organization features
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. STATE MANAGEMENT IMPROVEMENTS:
 *    - The current state management is good but could be more sophisticated
 *    - Consider adding more game organization features (folders, tags, etc.)
 *    - Add support for game organization presets
 *    - Implement smart game organization recommendations
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current game management could be more user-friendly
 *    - Add support for bulk operations (archive multiple games at once)
 *    - Implement drag-and-drop reordering
 *    - Add support for game organization tutorials
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient game list management
 *    - Add support for lazy loading of game organization data
 *    - Implement smart caching for game preferences
 * 
 * 4. TESTING IMPROVEMENTS:
 *    - Add comprehensive tests for game management logic
 *    - Test different game organization scenarios
 *    - Add UI tests for game management interactions
 *    - Test persistence and data integrity
 * 
 * 5. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for game management features
 *    - Document the different organization options and usage patterns
 *    - Add examples of how to use different game management features
 *    - Create game management usage guidelines
 * 
 * 6. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new game organization features
 *    - Add support for custom game organization configurations
 *    - Implement game organization plugins
 *    - Add support for third-party game organization integrations
 * 
 * 7. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add support for accessibility-enhanced game management
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for game management interactions
 *    - Implement metrics for game organization usage
 *    - Add support for game management debugging
 *    - Monitor game management performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - State management: Managing data that changes over time
 * - User preferences: Remembering what users want and how they want it
 * - Persistence: Saving data so it survives app restarts
 * - User experience: Making sure the app works the way users expect
 * - Data organization: Keeping information structured and accessible
 * - Customization: Allowing users to personalize their experience
 * - Reactive programming: Using @Published properties for automatic UI updates
 * - Code organization: Keeping related functionality together
 * - UserDefaults: A simple way to save small amounts of user data
 * - Collections: Using arrays and sets to manage groups of data
 */

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
