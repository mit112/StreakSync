//
//  AchievementCategoryFilter.swift
//  StreakSync
//
//  Category filter component for achievements
//

import SwiftUI

struct AchievementCategoryFilter: View {
    @Binding var selectedCategory: AchievementCategory?
    let categories: [AchievementCategory]
    let hasAppeared: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All categories chip
                CategoryChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                // Individual category chips
                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.baseIconSystemName,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .modifier(InitialAnimationModifier(
            hasAppeared: hasAppeared,
            index: 1,
            totalCount: 10
        ))
    }
}

// MARK: - Category Chip
private struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
            )
        }
        .pressable(scaleAmount: 0.9)
    }
}

// MARK: - Preview
#Preview {
    AchievementCategoryFilterPreviewWrapper()
}

private struct AchievementCategoryFilterPreviewWrapper: View {
    @State var selectedCategory: AchievementCategory? = nil

    var body: some View {
        AchievementCategoryFilter(
            selectedCategory: $selectedCategory,
            categories: AchievementCategory.allCases,
            hasAppeared: true
        )
        .padding()
    }
}
