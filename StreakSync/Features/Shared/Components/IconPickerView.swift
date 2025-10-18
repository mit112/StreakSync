//
//  IconPickerView.swift
//  StreakSync
//
//  Extracted from AddCustomGameView for better organization
//

/*
 * ICONPICKERVIEW - INTERACTIVE ICON SELECTION COMPONENT
 * 
 * WHAT THIS FILE DOES:
 * This file provides a beautiful, interactive icon picker component that allows users
 * to select icons from a curated collection of SF Symbols. It's like a "icon selection
 * interface" that presents icons in an attractive grid layout with visual feedback for
 * selection. Think of it as the "icon chooser system" that makes it easy and enjoyable
 * for users to pick icons for customizing games, categories, or other app elements.
 * 
 * WHY IT EXISTS:
 * The app needs a way for users to select icons for customizing their experience,
 * particularly when adding custom games or personalizing categories. Instead of using
 * basic system icon pickers, this component provides a curated, visually appealing
 * icon selection interface that's optimized for the app's design and use cases.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enables user customization and personalization
 * - Creates an intuitive, visual icon selection interface
 * - Provides a curated collection of icons optimized for the app
 * - Uses grid layout for easy browsing and selection
 * - Provides clear visual feedback for selected icons
 * - Makes icon selection feel engaging and user-friendly
 * - Supports customization features throughout the app
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and layout
 * - LazyVGrid: For efficient grid layout of icon options
 * - GridItem: For defining grid column configuration
 * - SafeSFSymbol: For safe icon display with fallbacks
 * - SFSymbolCompatibility: For handling different iOS versions
 * - NavigationStack: For modal presentation
 * 
 * WHAT REFERENCES IT:
 * - AddCustomGameView: Uses this for selecting game icons
 * - Category customization: Uses this for selecting category icons
 * - Settings views: Use this for icon preferences
 * - Customization features: Use this for user personalization
 * - Various feature views: Use this for icon selection needs
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. ICON COLLECTION IMPROVEMENTS:
 *    - The current collection is good but could be more comprehensive
 *    - Consider adding more icon categories and variations
 *    - Add support for custom icon collections
 *    - Implement smart icon recommendations based on context
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current icon picker could be more user-friendly
 *    - Add support for icon preview and comparison
 *    - Implement smart icon suggestions
 *    - Add support for icon search and filtering
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 4. VISUAL DESIGN IMPROVEMENTS:
 *    - The current visual design could be enhanced
 *    - Add support for more sophisticated icon representations
 *    - Implement smart visual adaptation for different contexts
 *    - Add support for dynamic icon effects
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient icon rendering
 *    - Add support for icon caching and reuse
 *    - Implement smart icon management
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for icon picker logic
 *    - Test different icon selections and scenarios
 *    - Add UI tests for icon picker interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for icon picker features
 *    - Document the different icon options and usage patterns
 *    - Add examples of how to use the icon picker
 *    - Create icon picker usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new icon options
 *    - Add support for custom icon configurations
 *    - Implement icon picker plugins
 *    - Add support for third-party icon integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Icon pickers: UI components that allow users to select icons
 * - SF Symbols: Apple's system icon library
 * - Grid layouts: Arranging items in a grid pattern for easy browsing
 * - User customization: Allowing users to personalize their experience
 * - Visual feedback: Providing users with information about their selections
 * - Interactive components: UI elements that respond to user input
 * - Modal presentation: Showing content in a separate screen
 * - Accessibility: Making sure icon selection works for all users
 * - User experience: Making sure icon selection is intuitive and enjoyable
 * - Component libraries: Collections of reusable UI components
 */

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
        "chart.bar", "chart.pie", SFSymbolCompatibility.getSymbol("chart.line.uptrend.xyaxis"), "target"
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
        Image.safeSystemName(icon, fallback: "questionmark.circle")
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
