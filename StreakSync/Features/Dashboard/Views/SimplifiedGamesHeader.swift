//
//  SimplifiedGamesHeader.swift
//  StreakSync
//
//  Clean, simplified games header with native iOS patterns
//

import SwiftUI

struct SimplifiedGamesHeader: View {
    @Binding var displayMode: GameDisplayMode
    @Binding var selectedSort: GameSortOption
    @Binding var sortDirection: SortDirection
    @Binding var showOnlyActive: Bool
    
    let navigateToGameManagement: () -> Void
    
    // Simplified display modes (just card and list)
    private var simplifiedDisplayModes: [GameDisplayMode] {
        [.card, .list]
    }
    
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
            
            // Row 2: View mode picker and sort menu
            HStack(spacing: 12) {
                // Native Segmented Control for view mode
                Picker("View Mode", selection: $displayMode) {
                    ForEach(simplifiedDisplayModes, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.iconName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                
                Spacer()
                
                // Active filter toggle
                Toggle(isOn: $showOnlyActive) {
                    Label("Active", systemImage: "flame.fill")
                        .font(.caption.weight(.medium))
                }
                .toggleStyle(CompactToggleStyle())
                
                // Unified sort menu
                UnifiedSortMenu(
                    selectedSort: $selectedSort,
                    sortDirection: $sortDirection
                )
            }
        }
    }
}

// MARK: - Unified Sort Menu
struct UnifiedSortMenu: View {
    @Binding var selectedSort: GameSortOption
    @Binding var sortDirection: SortDirection
    
    private var currentSortLabel: String {
        let directionSymbol = sortDirection == .ascending ? "↑" : "↓"
        return "\(selectedSort.shortName) \(directionSymbol)"
    }
    
    var body: some View {
        Menu {
            Section("Sort by") {
                ForEach(GameSortOption.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if selectedSort == option {
                                // Toggle direction if same option
                                sortDirection = sortDirection == .ascending ? .descending : .ascending
                            } else {
                                selectedSort = option
                                // Smart default directions
                                sortDirection = option == .name ? .ascending : .descending
                            }
                            HapticManager.shared.trigger(.buttonTap)
                        }
                    } label: {
                        HStack {
                            Label(option.rawValue, systemImage: option.icon)
                            if selectedSort == option {
                                Spacer()
                                Image(systemName: sortDirection == .ascending ? "arrow.up" : "arrow.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                Text(currentSortLabel)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.tertiarySystemFill))
            )
        }
    }
}

// MARK: - Compact Toggle Style
struct CompactToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
            HapticManager.shared.trigger(.toggleSwitch)
        } label: {
            HStack(spacing: 4) {
                if let label = configuration.label as? Label<Text, Image> {
                    Image(systemName: configuration.isOn ? "flame.fill" : "flame")
                        .font(.caption)
                        .foregroundStyle(configuration.isOn ? .orange : .secondary)
                }
                Text("Active")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(configuration.isOn ? .orange : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(configuration.isOn ? Color.orange.opacity(0.15) : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State var displayMode: GameDisplayMode = .card
        @State var selectedSort: GameSortOption = .lastPlayed
        @State var sortDirection: SortDirection = .descending
        @State var showOnlyActive: Bool = false
        
        var body: some View {
            VStack {
                SimplifiedGamesHeader(
                    displayMode: $displayMode,
                    selectedSort: $selectedSort,
                    sortDirection: $sortDirection,
                    showOnlyActive: $showOnlyActive,
                    navigateToGameManagement: {
                        print("Navigate to browse games")
                    }
                )
                .padding()
                
                Spacer()
            }
            .background(Color(.systemBackground))
        }
    }
    
    return PreviewWrapper()
}
