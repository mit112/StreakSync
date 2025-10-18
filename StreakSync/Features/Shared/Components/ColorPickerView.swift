//
//  ColorPickerView.swift
//  StreakSync
//
//  Extracted from AddCustomGameView for better organization
//

/*
 * COLORPICKERVIEW - INTERACTIVE COLOR SELECTION COMPONENT
 * 
 * WHAT THIS FILE DOES:
 * This file provides a beautiful, interactive color picker component that allows users
 * to select colors from a predefined palette. It's like a "color selection interface"
 * that presents colors in an attractive grid layout with visual feedback for selection.
 * Think of it as the "color chooser system" that makes it easy and enjoyable for users
 * to pick colors for customizing games, themes, or other app elements.
 * 
 * WHY IT EXISTS:
 * The app needs a way for users to select colors for customizing their experience,
 * particularly when adding custom games or personalizing themes. Instead of using
 * basic system color pickers, this component provides a curated, visually appealing
 * color selection interface that's optimized for the app's design and use cases.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enables user customization and personalization
 * - Creates an intuitive, visual color selection interface
 * - Provides a curated palette of colors optimized for the app
 * - Uses grid layout for easy browsing and selection
 * - Provides clear visual feedback for selected colors
 * - Makes color selection feel engaging and user-friendly
 * - Supports customization features throughout the app
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and layout
 * - LazyVGrid: For efficient grid layout of color options
 * - GridItem: For defining grid column configuration
 * - Color: For color representation and selection
 * - Circle: For creating color selection buttons
 * - NavigationStack: For modal presentation
 * 
 * WHAT REFERENCES IT:
 * - AddCustomGameView: Uses this for selecting game colors
 * - Theme customization: Uses this for selecting theme colors
 * - Settings views: Use this for color preferences
 * - Customization features: Use this for user personalization
 * - Various feature views: Use this for color selection needs
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. COLOR PALETTE IMPROVEMENTS:
 *    - The current palette is good but could be more sophisticated
 *    - Consider adding more color variations and shades
 *    - Add support for custom color palettes
 *    - Implement smart color recommendations based on context
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current color picker could be more user-friendly
 *    - Add support for color preview and comparison
 *    - Implement smart color suggestions
 *    - Add support for color accessibility features
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 4. VISUAL DESIGN IMPROVEMENTS:
 *    - The current visual design could be enhanced
 *    - Add support for more sophisticated color representations
 *    - Implement smart visual adaptation for different contexts
 *    - Add support for dynamic color effects
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient color rendering
 *    - Add support for color caching and reuse
 *    - Implement smart color management
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for color picker logic
 *    - Test different color selections and scenarios
 *    - Add UI tests for color picker interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for color picker features
 *    - Document the different color options and usage patterns
 *    - Add examples of how to use the color picker
 *    - Create color picker usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new color options
 *    - Add support for custom color configurations
 *    - Implement color picker plugins
 *    - Add support for third-party color integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Color pickers: UI components that allow users to select colors
 * - Grid layouts: Arranging items in a grid pattern for easy browsing
 * - User customization: Allowing users to personalize their experience
 * - Visual feedback: Providing users with information about their selections
 * - Interactive components: UI elements that respond to user input
 * - Modal presentation: Showing content in a separate screen
 * - Accessibility: Making sure color selection works for all users
 * - User experience: Making sure color selection is intuitive and enjoyable
 * - Component libraries: Collections of reusable UI components
 * - Design systems: Standardized approaches to creating consistent experiences
 */

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
