//
//  AddCustomGameSections.swift
//  StreakSync
//
//  Extracted sections from AddCustomGameView for better organization
//

/*
 * ADDCUSTOMGAMESECTIONS - MODULAR GAME CREATION INTERFACE COMPONENTS
 * 
 * WHAT THIS FILE DOES:
 * This file provides modular, reusable sections for the custom game creation interface,
 * breaking down the complex form into manageable, focused components. It's like a
 * "form section library" that creates a clean, organized interface for adding custom
 * games. Think of it as the "game creation toolkit" that makes it easy for users to
 * add their favorite games with proper organization, validation, and visual appeal.
 * 
 * WHY IT EXISTS:
 * Creating custom games requires a complex form with multiple sections and inputs.
 * Instead of having one massive view, this file breaks the form into logical,
 * reusable sections that are easier to maintain, test, and understand. It provides
 * a clean separation of concerns and makes the code more modular and maintainable.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enables users to add and customize their own games
 * - Creates a clean, organized interface for game creation
 * - Breaks down complex forms into manageable sections
 * - Supports different iOS versions with appropriate UI components
 * - Provides proper validation and user feedback
 * - Makes game creation feel intuitive and user-friendly
 * - Supports customization with icons, colors, and categories
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and layout
 * - GameCategory: For categorizing custom games
 * - iOS26TextFieldStyle: For modern text field styling
 * - iOS26CategoryPicker: For category selection
 * - ColorPickerView: For color selection
 * - IconPickerView: For icon selection
 * - StreakSyncColors: For consistent theming
 * 
 * WHAT REFERENCES IT:
 * - AddCustomGameView: Uses these sections to build the complete form
 * - Game customization: Uses these sections for game configuration
 * - Settings views: Use these sections for game management
 * - Customization features: Use these sections for user personalization
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. SECTION ORGANIZATION IMPROVEMENTS:
 *    - The current organization is good but could be more modular
 *    - Consider adding more section variations and configurations
 *    - Add support for custom section layouts
 *    - Implement smart section selection based on context
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current sections could be more user-friendly
 *    - Add support for section customization and preferences
 *    - Implement smart section recommendations
 *    - Add support for section tutorials and guidance
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 4. VISUAL DESIGN IMPROVEMENTS:
 *    - The current visual design could be enhanced
 *    - Add support for more sophisticated visual elements
 *    - Implement smart visual adaptation for different contexts
 *    - Add support for dynamic visual elements
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient section rendering
 *    - Add support for section caching and reuse
 *    - Implement smart section management
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for section logic
 *    - Test different section configurations and scenarios
 *    - Add UI tests for section interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for section features
 *    - Document the different section types and usage patterns
 *    - Add examples of how to use different sections
 *    - Create section usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new section types
 *    - Add support for custom section configurations
 *    - Implement section plugins
 *    - Add support for third-party section integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Form sections: Breaking down complex forms into manageable parts
 * - Modular design: Creating reusable, focused components
 * - User interface: Designing clean, organized interfaces
 * - Form validation: Ensuring user input is correct and complete
 * - User experience: Making sure forms are easy to use and understand
 * - Accessibility: Making sure forms work for all users
 * - Visual design: Creating appealing and informative interfaces
 * - Component libraries: Collections of reusable UI components
 * - Code organization: Keeping related functionality together
 * - Design systems: Standardized approaches to creating consistent experiences
 */

import SwiftUI

// MARK: - iOS 26 Header Section
@available(iOS 26.0, *)
struct AddCustomGameHeaderSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let showingSuccessHaptic: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.app")
                .font(.system(size: 48))
                .foregroundStyle(StreakSyncColors.primary(for: colorScheme))
                .symbolEffect(.bounce, value: showingSuccessHaptic)
            
            Text("Add Your Favorite Puzzle")
                .font(.title3.weight(.semibold))
            
            Text("Track any daily puzzle game by adding it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
}

// MARK: - iOS 26 Basic Info Section
@available(iOS 26.0, *)
struct AddCustomGameBasicInfoSection: View {
    @Binding var gameName: String
    @Binding var gameURL: String
    @Binding var selectedCategory: GameCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Basic Information", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 16) {
                // Game Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Name")
                        .font(.subheadline.weight(.medium))
                    
                    TextField("e.g., Wordle, Connections", text: $gameName)
                        .textFieldStyle(iOS26TextFieldStyle())
                }
                
                // Game URL Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game URL")
                        .font(.subheadline.weight(.medium))
                    
                    TextField("https://example.com", text: $gameURL)
                        .textFieldStyle(iOS26TextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                // Category Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.subheadline.weight(.medium))
                    
                    iOS26CategoryPicker(selection: $selectedCategory)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - iOS 26 Appearance Section
@available(iOS 26.0, *)
struct AddCustomGameAppearanceSection: View {
    @Binding var selectedIcon: String
    @Binding var selectedColor: Color
    @Binding var showingIconPicker: Bool
    @Binding var showingColorPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Appearance", systemImage: "paintbrush")
                .font(.headline)
                .foregroundStyle(.primary)
            
            HStack(spacing: 20) {
                // Icon Selection
                VStack(spacing: 8) {
                    Text("Icon")
                        .font(.subheadline.weight(.medium))
                    
                    Button(action: { showingIconPicker = true }) {
                        Image.safeSystemName(selectedIcon, fallback: "gamecontroller")
                            .font(.title2)
                            .foregroundStyle(selectedColor)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                
                // Color Selection
                VStack(spacing: 8) {
                    Text("Color")
                        .font(.subheadline.weight(.medium))
                    
                    Button(action: { showingColorPicker = true }) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 50, height: 50)
                            .overlay {
                                Circle()
                                    .stroke(.quaternary, lineWidth: 1)
                            }
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - iOS 26 Advanced Section
@available(iOS 26.0, *)
struct AddCustomGameAdvancedSection: View {
    @Binding var resultPattern: String
    @Binding var exampleResult: String
    @Binding var showingPatternHelper: Bool
    let selectedCategory: GameCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Advanced Settings", systemImage: "gearshape")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 16) {
                // Result Pattern Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Result Pattern")
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        Button("Help") {
                            showingPatternHelper = true
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                    
                    TextField("Regex pattern to detect results", text: $resultPattern)
                        .textFieldStyle(iOS26TextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                }
                
                // Example Result Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example Result")
                        .font(.subheadline.weight(.medium))
                    
                    TextField("Paste an example result here", text: $exampleResult, axis: .vertical)
                        .textFieldStyle(iOS26TextFieldStyle())
                        .lineLimit(3...6)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - iOS 26 Preview Section
@available(iOS 26.0, *)
struct AddCustomGamePreviewSection: View {
    let gameName: String
    let selectedIcon: String
    let selectedColor: Color
    let selectedCategory: GameCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Preview", systemImage: "eye")
                .font(.headline)
                .foregroundStyle(.primary)
            
            HStack(spacing: 16) {
                // Game Icon
                Image.safeSystemName(selectedIcon, fallback: "gamecontroller")
                    .font(.title)
                    .foregroundStyle(selectedColor)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(gameName.isEmpty ? "Game Name" : gameName)
                        .font(.headline)
                        .foregroundStyle(gameName.isEmpty ? .secondary : .primary)
                    
                    Text(selectedCategory.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        if #available(iOS 26.0, *) {
            AddCustomGameHeaderSection(showingSuccessHaptic: false)
            
            AddCustomGameBasicInfoSection(
                gameName: .constant("Wordle"),
                gameURL: .constant("https://wordle.com"),
                selectedCategory: .constant(.word)
            )
            
            AddCustomGameAppearanceSection(
                selectedIcon: .constant("gamecontroller"),
                selectedColor: .constant(.blue),
                showingIconPicker: .constant(false),
                showingColorPicker: .constant(false)
            )
        }
    }
    .padding()
}
