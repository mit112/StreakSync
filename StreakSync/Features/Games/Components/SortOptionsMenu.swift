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
    case completionRate = "Success Rate"  // ADD THIS LINE
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .lastPlayed:
            return "clock"
        case .name:
            return "textformat"
        case .streakLength:
            return "flame"
        case .completionRate:  // ADD THIS CASE
            return "percent"
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
        case .completionRate:  // ADD THIS CASE
            return "Success"
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

// MARK: - Sort Options Menu View
struct SortOptionsMenu: View {
    @Binding var selectedSort: GameSortOption
    @Binding var sortDirection: SortDirection
    
    var body: some View {
        Menu {
            ForEach(GameSortOption.allCases) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if selectedSort == option {
                            // Toggle direction if same option selected
                            sortDirection = sortDirection == .ascending ? .descending : .ascending
                        } else {
                            selectedSort = option
                            // Default to descending for streak length, ascending for name
                            sortDirection = option == .name ? .ascending : .descending
                        }
                        HapticManager.shared.trigger(.buttonTap)
                    }
                } label: {
                    Label(option.rawValue, systemImage: option.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image.safeSystemName(selectedSort.icon, fallback: "arrow.up.arrow.down")
                    .font(.caption)
                Image.safeSystemName(sortDirection.icon, fallback: "arrow.up")
                    .font(.caption2)
            }
            .foregroundStyle(.blue)
            .padding(8)
            .background(
                Circle()
                    .fill(.blue.opacity(0.1))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel("Sort options")
        .accessibilityHint("Currently sorted by \(selectedSort.rawValue) in \(sortDirection.rawValue) order")
    }
}

// Alternative compact version if you prefer text + icon:
struct CompactSortOptionsMenu: View {
    @Binding var selectedSort: GameSortOption
    @Binding var sortDirection: SortDirection
    
    var body: some View {
        Menu {
            ForEach(GameSortOption.allCases) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if selectedSort == option {
                            // Toggle direction if same option selected
                            sortDirection = sortDirection == .ascending ? .descending : .ascending
                        } else {
                            selectedSort = option
                            // Default to descending for streak length, ascending for name
                            sortDirection = option == .name ? .ascending : .descending
                        }
                        HapticManager.shared.trigger(.buttonTap)
                    }
                } label: {
                    Label(option.rawValue, systemImage: option.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedSort.shortName)
                    .font(.caption.weight(.medium))
                Image.safeSystemName(sortDirection.icon, fallback: "arrow.up")
                    .font(.caption2)
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.blue.opacity(0.1))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel("Sort options")
        .accessibilityHint("Currently sorted by \(selectedSort.rawValue) in \(sortDirection.rawValue) order")
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

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Text("Icon only version:")
        SortOptionsMenu(
            selectedSort: .constant(.lastPlayed),
            sortDirection: .constant(.descending)
        )
        
        Text("Text + direction version:")
        CompactSortOptionsMenu(
            selectedSort: .constant(.streakLength),
            sortDirection: .constant(.ascending)
        )
    }
    .padding()
}
