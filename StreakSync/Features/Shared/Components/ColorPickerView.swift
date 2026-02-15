//
//  ColorPickerView.swift
//  StreakSync
//
//  Extracted from AddCustomGameView for better organization
//

import SwiftUI

// MARK: - Color Picker View
struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    
    private let colors: [Color] = [
        .red, .orange, .yellow, .green,
        .mint, .teal, .cyan, .blue,
        .indigo, .purple, .pink, .brown,
        .gray, .black
    ]
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 4)
    }
    
    var body: some View {
        NavigationStack {
            colorGrid
                .navigationTitle("Choose Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        doneButton
                    }
                }
        }
    }
    
    private var colorGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(colors, id: \.self) { color in
                    ColorButton(
                        color: color,
                        isSelected: selectedColor == color,
                        action: {
                            selectedColor = color
                            dismiss()
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var doneButton: some View {
        Button("Done") {
            dismiss()
        }
    }
}

// MARK: - Color Button Component
struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            colorCircle
        }
    }
    
    private var colorCircle: some View {
        Circle()
            .fill(color)
            .frame(width: 60, height: 60)
            .overlay(selectionRing)
    }
    
    @ViewBuilder
    private var selectionRing: some View {
        if isSelected {
            Circle()
                .stroke(.white, lineWidth: 3)
                .padding(2)
        }
    }
}

// MARK: - Preview
#Preview {
    ColorPickerView(selectedColor: .constant(.blue))
}
