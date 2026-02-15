//
//  iOS26FormComponents.swift
//  StreakSync
//
//  Extracted from AddCustomGameView for better organization
//

import SwiftUI

// MARK: - iOS 26 Text Field Style
struct iOS26TextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.quaternary, lineWidth: 0.5)
                    }
            }
    }
}

// MARK: - iOS 26 Category Picker
struct iOS26CategoryPicker: View {
    @Binding var selection: GameCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GameCategory.allCases.filter { $0 != .custom }, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selection == category
                    ) {
                        withAnimation(.smooth(duration: 0.2)) {
                            selection = category
                        }
                    }
                }
            }
        }
    }
    
    private struct CategoryChip: View {
        let category: GameCategory
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image.safeSystemName(category.iconSystemName, fallback: "folder")
                        .font(.caption)
                    Text(category.displayName)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                }
            }
            .hoverEffect(.highlight)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        TextField("Test Field", text: .constant(""))
            .textFieldStyle(iOS26TextFieldStyle())
        
        iOS26CategoryPicker(selection: .constant(.word))
    }
    .padding()
}
