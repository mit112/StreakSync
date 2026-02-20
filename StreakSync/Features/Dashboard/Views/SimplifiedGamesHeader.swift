//
//  SimplifiedGamesHeader.swift
//  StreakSync
//
//  Clean, simplified games header with native iOS patterns
//

import SwiftUI

struct SimplifiedGamesHeader: View {
    @Binding var selectedSort: GameSortOption
    @Binding var sortDirection: SortDirection
    @Binding var showOnlyActive: Bool
    @Binding var selectedCategory: GameCategory?
    
    let navigateToGameManagement: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Row 1: Title and Browse button
            HStack {
                Text("Your Games")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                // Primary CTA: Browse Games
                Button {
                    navigateToGameManagement()
                    HapticManager.shared.trigger(.buttonTap)
                } label: {
                    Label("Browse", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            // Row 2: Active filter chips (only when filters applied)
            let hasFilters = showOnlyActive || selectedCategory != nil
            if hasFilters {
                HStack(spacing: 8) {
                    if showOnlyActive {
                        FilterChip(
                            label: "Active",
                            icon: "flame.fill",
                            color: .orange,
                            onRemove: { showOnlyActive = false }
                        )
                    }
                    
                    if let selectedCategory = selectedCategory {
                        FilterChip(
                            label: selectedCategory.displayName,
                            icon: selectedCategory.iconSystemName,
                            color: .blue,
                            onRemove: { self.selectedCategory = nil }
                        )
                    }
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: showOnlyActive)
        .animation(.smooth(duration: 0.25), value: selectedCategory)
    }
}

// MARK: - Filter Chip (Dismissible Filter Tag)
struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image.safeSystemName(icon, fallback: "number")
                .font(.caption2.weight(.semibold))
            
            Text(label)
                .font(.caption.weight(.medium))
            
            Button {
                HapticManager.shared.trigger(.buttonTap)
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(color)
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Toolbar Sort Menu (System-Owned Presentation)
// This lives in the toolbar for smooth native Menu animations
struct ToolbarSortMenu: View {
    @Binding var selectedSort: GameSortOption
    @Binding var sortDirection: SortDirection
    @Binding var showOnlyActive: Bool
    @Binding var displayMode: GameDisplayMode
    
    var body: some View {
        Menu {
            menuContent
        } label: {
            // Static icon - no dynamic content to trigger relayout
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)
        }
        .menuOrder(.fixed)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Double tap to change sort and filter options")
    }
    
    @ViewBuilder
    private var menuContent: some View {
        // Section 1: View mode + active filter
        Section {
            Button {
                displayMode = displayMode == .card ? .grid : .card
                HapticManager.shared.trigger(.toggleSwitch)
            } label: {
                Label(
                    displayMode == .card ? "Grid View" : "List View",
                    systemImage: displayMode == .card ? "square.grid.2x2" : "list.bullet"
                )
            }
            
            Button {
                showOnlyActive.toggle()
                HapticManager.shared.trigger(.toggleSwitch)
            } label: {
                Label("Active Only", systemImage: showOnlyActive ? "checkmark" : "circle")
            }
        }
        
        // Section 2: Sort options with direction indicators
        Section("Sort By") {
            ForEach(GameSortOption.allCases) { option in
                Button {
                    handleSortSelection(option)
                } label: {
                    if selectedSort == option {
                        // Selected option with direction arrow inline
                        Text("\(option.rawValue) \(sortDirection == .ascending ? "↑" : "↓")")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        }
    }
    
    private func handleSortSelection(_ option: GameSortOption) {
        // Direct state update - no animations to interfere with Menu dismissal
        if selectedSort == option {
            sortDirection = sortDirection == .ascending ? .descending : .ascending
        } else {
            selectedSort = option
            sortDirection = option == .name ? .ascending : .descending
        }
        HapticManager.shared.trigger(.buttonTap)
    }
    
    private var accessibilityText: String {
        let direction = sortDirection == .ascending ? "ascending" : "descending"
        return "Sort by \(selectedSort.rawValue), \(direction)"
    }
}

// MARK: - Preview
#Preview("Games Header") {
    struct PreviewWrapper: View {
        @State var displayMode: GameDisplayMode = .card
        @State var selectedSort: GameSortOption = .lastPlayed
        @State var sortDirection: SortDirection = .descending
        @State var showOnlyActive: Bool = false
        @State var selectedCategory: GameCategory? = nil
        
        var body: some View {
            VStack(spacing: 20) {
                SimplifiedGamesHeader(
                    selectedSort: $selectedSort,
                    sortDirection: $sortDirection,
                    showOnlyActive: $showOnlyActive,
                    selectedCategory: $selectedCategory,
                    navigateToGameManagement: {
                        // preview action
                    }
                )
                .padding()
                
                // Debug info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current State:")
                        .font(.caption.bold())
                    Text("Display: \(displayMode.displayName)")
                    Text("Sort: \(selectedSort.rawValue) \(sortDirection == .ascending ? "↑" : "↓")")
                    Text("Active Only: \(showOnlyActive ? "Yes" : "No")")
                    Text("Category: \(selectedCategory?.displayName ?? "None")")
                }
                .font(.caption)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding()
                
                Spacer()
            }
            .background(Color(.systemBackground))
        }
    }
    
    return PreviewWrapper()
}

#Preview("Filter Components") {
    VStack(spacing: 20) {
        // Filter Chip
        FilterChip(
            label: "Active",
            icon: "flame.fill",
            color: .orange,
            onRemove: { print("Remove filter") }
        )
        
        // Toolbar Sort Menu (now lives in toolbar)
        ToolbarSortMenu(
            selectedSort: .constant(.lastPlayed),
            sortDirection: .constant(.descending),
            showOnlyActive: .constant(false),
            displayMode: .constant(.card)
        )
        
        Divider()
        
        Text("Sort state is shown within the menu itself")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
    .background(Color(.systemBackground))
}

