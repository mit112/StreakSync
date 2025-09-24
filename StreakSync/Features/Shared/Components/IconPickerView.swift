//
//  IconPickerView.swift
//  StreakSync
//
//  Extracted from AddCustomGameView for better organization
//

import SwiftUI

// MARK: - Icon Picker View
struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    private let icons = [
        "gamecontroller", "dice", "puzzlepiece", "star",
        "crown", "flag", "map", "globe",
        "book", "pencil", "scribble", "brain",
        "lightbulb", "sparkles", "wand.and.stars", "atom",
        "function", "number", "textformat.abc", "doc.text",
        "music.note", "headphones", "speaker.wave.2", "guitars",
        "photo", "camera", "paintbrush", "paintpalette",
        "hammer", "wrench", "gearshape", "cpu",
        "hourglass", "timer", "clock", "calendar",
        "chart.bar", "chart.pie", "chart.line.uptrend.xyaxis", "target"
    ]
    
    // Break down grid columns into a computed property
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 4)
    }
    
    var body: some View {
        NavigationStack {
            iconGrid
                .navigationTitle("Choose Icon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        doneButton
                    }
                }
        }
    }
    
    // Extract the scroll view and grid
    private var iconGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(icons, id: \.self) { icon in
                    IconPickerButton(
                        icon: icon,
                        isSelected: selectedIcon == icon,
                        action: {
                            selectedIcon = icon
                            dismiss()
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // Extract the done button
    private var doneButton: some View {
        Button("Done") {
            dismiss()
        }
    }
}

// MARK: - Icon Picker Button Component
struct IconPickerButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            iconContent
        }
        .foregroundStyle(iconColor)
    }
    
    private var iconContent: some View {
        Image(systemName: icon)
            .font(.title)
            .frame(width: 60, height: 60)
            .background(backgroundCircle)
    }
    
    @ViewBuilder
    private var backgroundCircle: some View {
        if isSelected {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
        }
    }
    
    private var iconColor: Color {
        isSelected ? .accentColor : .primary
    }
}

// MARK: - Preview
#Preview {
    IconPickerView(selectedIcon: .constant("gamecontroller"))
}
