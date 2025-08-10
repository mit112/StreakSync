//
//  CategoryFilterView.swift
//  StreakSync
//
//  A horizontal scrollable chip-based filter for game categories
//

import SwiftUI

struct CategoryFilterView: View {
    @Binding var selectedCategory: GameCategory?
    let categories: [GameCategory]
    
    @State private var scrollPosition: GameCategory?
    @Environment(\.colorScheme) private var colorScheme
    
    private let allCategoriesId = "all_categories" // Define a constant for the ID
    
    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All categories chip
                    CategoryChip(
                        title: "All",
                        icon: "square.grid.2x2",
                        isSelected: selectedCategory == nil,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedCategory = nil
                                HapticManager.shared.trigger(.buttonTap)
                            }
                        }
                    )
                    .id(allCategoriesId) // Use the constant
                    
                    // Category chips
                    ForEach(categories, id: \.self) { category in
                        CategoryChip(
                            title: category.displayName,
                            icon: categoryIcon(for: category),
                            isSelected: selectedCategory == category,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedCategory = category
                                    HapticManager.shared.trigger(.buttonTap)
                                }
                            }
                        )
                        .id(category.rawValue) // Use the raw value as ID for consistency
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            .onChange(of: selectedCategory) { _, newValue in
                withAnimation {
                    if let category = newValue {
                        proxy.scrollTo(category.rawValue, anchor: .center)
                    } else {
                        proxy.scrollTo(allCategoriesId, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func categoryIcon(for category: GameCategory) -> String {
        switch category {
        case .word:
            return "textformat"
        case .math:
            return "function"
        case .music:
            return "music.note"
        case .geography:
            return "globe"
        case .trivia:
            return "lightbulb"
        case .puzzle:
            return "puzzlepiece"
        case .custom:
            return "star"
        }
    }
}

// MARK: - Category Chip Component
private struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .symbolEffect(.bounce, value: isSelected)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : chipBackgroundColor)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? Color.clear : Color(.separator).opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) category")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    
    private var chipBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Light mode preview
        CategoryFilterView(
            selectedCategory: .constant(nil),
            categories: GameCategory.allCases.filter { $0 != .custom }
        )
        .preferredColorScheme(.light)
        
        // Dark mode preview with selection
        CategoryFilterView(
            selectedCategory: .constant(.word),
            categories: GameCategory.allCases.filter { $0 != .custom }
        )
        .preferredColorScheme(.dark)
    }
    .padding(.vertical)
}
