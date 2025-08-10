//
//  GameSection.swift
//  StreakSync
//
//  Game section types for dashboard organization
//

import Foundation

enum GameSection: String, CaseIterable {
    case favorites = "Favorites"
    case all = "All Games"
    
    var icon: String {
        switch self {
        case .favorites: return "star.fill"
        case .all: return "gamecontroller"
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .favorites: return "No favorite games yet. Tap the star icon to add favorites."
        case .all: return "No games available."
        }
    }
}
