//
//  GameAppEntity.swift
//  StreakSyncWidget
//
//  The pickable game entity backing widget configuration and Shortcuts
//

import AppIntents
import Foundation

/// A game the user can pick, backed by the compile-time catalog in
/// `GameDefinitions.swift`. `Game.allAvailableGames` is a static constant with no
/// I/O and no main-actor isolation, so the query is safe from the widget process
/// and from Shortcuts alike — unlike `GameCatalog`, which is a `@MainActor`
/// singleton over `UserDefaults.standard` and unreachable here.
struct GameAppEntity: AppEntity, Identifiable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Game")
    static let defaultQuery = GameEntityQuery()

    let id: UUID
    let displayName: String
    let iconSystemName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            image: DisplayRepresentation.Image(systemName: iconSystemName)
        )
    }

    init(game: Game) {
        self.id = game.id
        self.displayName = game.displayName
        self.iconSystemName = game.iconSystemName
    }
}

struct GameEntityQuery: EntityStringQuery {
    func entities(for identifiers: [GameAppEntity.ID]) async throws -> [GameAppEntity] {
        let wanted = Set(identifiers)
        return Game.allAvailableGames
            .filter { wanted.contains($0.id) }
            .map { GameAppEntity(game: $0) }
    }

    /// Siri and Shortcuts resolve a spoken or typed name through here. Matching
    /// covers both the display name ("Mini Crossword") and the slug
    /// ("minicrossword"), because the slug is what the share pipeline uses.
    func entities(matching string: String) async throws -> [GameAppEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            return try await suggestedEntities()
        }
        return Game.allAvailableGames
            .filter {
                $0.displayName.localizedCaseInsensitiveContains(needle)
                    || $0.name.localizedCaseInsensitiveContains(needle)
            }
            .map { GameAppEntity(game: $0) }
    }

    func suggestedEntities() async throws -> [GameAppEntity] {
        Game.allAvailableGames.map { GameAppEntity(game: $0) }
    }

    func defaultResult() async -> GameAppEntity? {
        Game.allAvailableGames.first.map { GameAppEntity(game: $0) }
    }
}
