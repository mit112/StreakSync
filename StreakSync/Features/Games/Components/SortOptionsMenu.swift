//
//  SortOptionsMenu.swift
//  StreakSync
//
//  Sorting options dropdown for game lists
//

import SwiftUI

// MARK: - Sort Option Enum
enum GameSortOption: String, CaseIterable, Identifiable {
    case lastPlayed = "Last Played"
    case name = "Name"
    case streakLength = "Streak Length"
    case completionRate = "Success Rate"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .lastPlayed:
            return "clock"
        case .name:
            return "textformat"
        case .streakLength:
            return "flame"
        case .completionRate:            return "percent"
        }
    }
    
    var shortName: String {
        switch self {
        case .lastPlayed:
            return "Recent"
        case .name:
            return "A-Z"
        case .streakLength:
            return "Streak"
        case .completionRate:            return "Success"
        }
    }
}
// MARK: - Sort Direction Enum
enum SortDirection: String, CaseIterable {
    case ascending = "Ascending"
    case descending = "Descending"
    
    var icon: String {
        switch self {
        case .ascending:
            return "chevron.up"
        case .descending:
            return "chevron.down"
        }
    }
}

// MARK: - Sort Function Extension
extension Array where Element == GameStreak {
    func sorted(by option: GameSortOption, direction: SortDirection, games: [Game]) -> [GameStreak] {
        sorted { streak1, streak2 in
            let ascending: Bool
            
            switch option {
            case .lastPlayed:
                let date1 = streak1.lastPlayedDate ?? Date.distantPast
                let date2 = streak2.lastPlayedDate ?? Date.distantPast
                ascending = date1 < date2
                
            case .name:
                ascending = streak1.gameName < streak2.gameName
                
            case .streakLength:
                ascending = streak1.currentStreak < streak2.currentStreak
                
            case .completionRate:
                // Add the implementation for completion rate sorting
                ascending = streak1.completionRate < streak2.completionRate
            }
            
            return direction == .ascending ? ascending : !ascending
        }
    }
}

