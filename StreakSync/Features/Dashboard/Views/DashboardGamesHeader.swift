//
//  DashboardGamesHeader.swift
//  StreakSync
//
//  Games section header with display mode and sort controls
//

import SwiftUI

struct DashboardGamesHeader: View {
    @Binding var displayMode: GameDisplayMode
    @Binding var selectedSort: GameSortOption
    @Binding var sortDirection: SortDirection
    @Binding var selectedGameSection: GameSection
    @Binding var selectedCategory: GameCategory?
    
    let navigateToGameManagement: () -> Void
    
    var body: some View {
        HStack {
            Text("Your Games")
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            // View mode toggle
            Menu {
                ForEach(GameDisplayMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            displayMode = mode
                            HapticManager.shared.trigger(.buttonTap)
                        }
                    } label: {
                        Label(mode.displayName, systemImage: mode.iconName)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: displayMode.iconName)
                        .font(.body)
                    Text(displayMode.displayName)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.blue.opacity(0.1))
                )
            }
            
            // Sort options
            CompactSortOptionsMenu(
                selectedSort: $selectedSort,
                sortDirection: $sortDirection
            )
            
            // Section selector
            Menu {
                ForEach(GameSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedGameSection = section
                            selectedCategory = nil
                        }
                    } label: {
                        Label(section.rawValue, systemImage: section.icon)
                    }
                }
                
                Divider()
                
                Button {
                    navigateToGameManagement()
                } label: {
                    Label("Manage Games", systemImage: "slider.horizontal.3")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedGameSection.icon)
                    Text(selectedGameSection.rawValue)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    struct HeaderPreview: View {
        @State var displayMode: GameDisplayMode = .card
        @State var selectedSort: GameSortOption = .lastPlayed
        @State var sortDirection: SortDirection = .descending
        @State var selectedGameSection: GameSection = .all
        @State var selectedCategory: GameCategory? = nil

        var body: some View {
            DashboardGamesHeader(
                displayMode: $displayMode,
                selectedSort: $selectedSort,
                sortDirection: $sortDirection,
                selectedGameSection: $selectedGameSection,
                selectedCategory: $selectedCategory,
                navigateToGameManagement: {
                    print("Navigate to game management")
                }
            )
        }
    }

    return HeaderPreview()
}
