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
    /// The order saved by drag-to-reorder in Manage Games. It has no direction.
    case custom = "My Order"
    
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
        case .custom:
            return "line.3.horizontal"
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
