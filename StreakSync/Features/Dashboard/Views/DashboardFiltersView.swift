//
//  DashboardFiltersView.swift
//  StreakSync
//
//  Filter controls for dashboard (active toggle and category filter)
//

import SwiftUI

struct DashboardFiltersView: View {
    @Binding var showOnlyActive: Bool
    @Binding var selectedCategory: GameCategory?
    let availableCategories: [GameCategory]
    
    var body: some View {
        VStack(spacing: 12) {
            // Active only toggle
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showOnlyActive.toggle()
                    }
                } label: {
                    Label("Active", systemImage: showOnlyActive ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(showOnlyActive ? .orange : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(showOnlyActive ? .orange.opacity(0.15) : Color(.tertiarySystemFill))
                        )
                }
                .pressable(hapticType: .toggleSwitch, scaleAmount: 0.95)
                .accessibilityLabel(showOnlyActive ? "Showing active games only" : "Show all games")
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Category filter chips
            if !availableCategories.isEmpty {
                CategoryFilterView(
                    selectedCategory: $selectedCategory,
                    categories: availableCategories
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    DashboardFiltersPreviewWrapper()
}
private struct DashboardFiltersPreviewWrapper: View {
    @State var showOnlyActive = true
    @State var selectedCategory: GameCategory? = .word

    var body: some View {
        DashboardFiltersView(
            showOnlyActive: $showOnlyActive,
            selectedCategory: $selectedCategory,
            availableCategories: GameCategory.allCases
        )
    }
}
