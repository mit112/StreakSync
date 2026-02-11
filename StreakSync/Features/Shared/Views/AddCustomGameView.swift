//
//  AddCustomGameView.swift
//  StreakSync
//
//  Custom game addition with iOS 26 materials and comprehensive validation
//  REFACTORED: Extracted components for better organization
//

/*
 * ADDCUSTOMGAMEVIEW - USER-DEFINED GAME CREATION SYSTEM
 * 
 * WHAT THIS FILE DOES:
 * This file creates a comprehensive form that allows users to add their own custom games
 * to the app. It's like a "game creation wizard" that guides users through the process
 * of defining a new game, including its name, URL, category, icon, color, and result
 * parsing pattern. Think of it as the "game designer" that lets users extend the app
 * with their own games and customize how results are parsed and displayed.
 * 
 * WHY IT EXISTS:
 * Not all games are built into the app, and users might want to track games that aren't
 * officially supported. This view provides a user-friendly way to add custom games
 * with proper validation, pattern matching, and integration with the app's existing
 * systems. It ensures that custom games work seamlessly with the rest of the app's
 * features like streaks, achievements, and analytics.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enables users to extend the app with their own games
 * - Provides a comprehensive form for game creation and configuration
 * - Includes validation and error handling for user input
 * - Supports custom icons, colors, and result parsing patterns
 * - Handles different iOS versions with appropriate features
 * - Integrates with the app's existing game management system
 * - Ensures custom games work with all app features
 * 
 * WHAT IT REFERENCES:
 * - GameCatalog: For managing the list of available games
 * - AppState: For adding new games to the app's data
 * - GameCategory: Categories for organizing games
 * - IconPickerView: For selecting custom game icons
 * - ColorPickerView: For selecting custom game colors
 * - PatternHelperView: For creating result parsing patterns
 * - SwiftUI Form: For creating a clean, native iOS form interface
 * 
 * WHAT REFERENCES IT:
 * - Settings: Can navigate to this view for game management
 * - Game management views: Can navigate to this view
 * - NavigationCoordinator: Manages navigation to this view
 * - AppContainer: Provides the data and services this view needs
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. FORM ORGANIZATION:
 *    - The current form is large - could be better organized
 *    - Consider separating into multiple steps or sections
 *    - Add support for form templates and presets
 *    - Implement smart form validation and suggestions
 * 
 * 2. VALIDATION IMPROVEMENTS:
 *    - The current validation is basic - could be more sophisticated
 *    - Add real-time validation as users type
 *    - Implement smart error correction and suggestions
 *    - Add support for different validation rules per game type
 * 
 * 3. USER EXPERIENCE IMPROVEMENTS:
 *    - The current form could be more intuitive
 *    - Add support for form auto-save and recovery
 *    - Implement smart defaults based on game category
 *    - Add support for form preview and testing
 * 
 * 4. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for form logic
 *    - Test different validation scenarios and edge cases
 *    - Add UI tests for form interactions
 *    - Test accessibility features
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for form features
 *    - Document the validation rules and patterns
 *    - Add examples of how to create different game types
 *    - Create form flow diagrams
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new game types
 *    - Add support for custom validation rules
 *    - Implement game creation plugins
 *    - Add support for third-party game integrations
 * 
 * 8. ERROR HANDLING:
 *    - The current error handling is basic - could be more robust
 *    - Add support for different error types and recovery
 *    - Implement user-friendly error messages
 *    - Add support for error reporting and feedback
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Forms: User interfaces for collecting and submitting data
 * - Validation: Checking that user input is correct and complete
 * - Custom games: Games that users can add to the app themselves
 * - Pattern matching: Using rules to parse and understand text
 * - User experience: Making sure the app is easy and pleasant to use
 * - Accessibility: Making sure the app is usable for everyone
 * - iOS version compatibility: Making sure the app works on different iOS versions
 * - Error handling: What to do when something goes wrong
 * - State management: Keeping track of what the user has entered
 * - Data binding: Connecting UI elements to data that can change
 */

import SwiftUI

// MARK: - Add Custom Game View
struct AddCustomGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(GameCatalog.self) private var gameCatalog
    @Environment(AppState.self) private var appState
    
    // Form fields
    @State private var gameName = ""
    @State private var gameURL = ""
    @State private var selectedCategory: GameCategory = .word
    @State private var selectedIcon = "gamecontroller"
    @State private var selectedColor = Color.blue
    @State private var resultPattern = ""
    @State private var exampleResult = ""
    
    // UI State
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false
    @State private var showingPatternHelper = false
    @State private var isValidating = false
    @State private var validationError: ValidationError?
    @State private var showingSuccessHaptic = false
    
    // Validation
    private var isFormValid: Bool {
        !gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !gameURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        URL(string: gameURL) != nil
    }
    
    private enum ValidationError: LocalizedError {
        case invalidURL
        case duplicateName
        case invalidPattern
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Please enter a valid URL starting with https://"
            case .duplicateName:
                return "A game with this name already exists"
            case .invalidPattern:
                return "The result pattern couldn't be validated"
            case .networkError:
                return "Couldn't verify the URL. Check your connection."
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            if #available(iOS 26.0, *) {
                iOS26FormContent
            } else {
                legacyFormContent
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $selectedColor)
        }
        .sheet(isPresented: $showingPatternHelper) {
            PatternHelperView(
                pattern: $resultPattern,
                exampleResult: $exampleResult,
                category: selectedCategory
            )
        }
        .alert("Validation Error", isPresented: .constant(validationError != nil)) {
            Button("OK") {
                validationError = nil
            }
        } message: {
            if let error = validationError {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - iOS 26 Form
    @available(iOS 26.0, *)
    private var iOS26FormContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                AddCustomGameHeaderSection(showingSuccessHaptic: showingSuccessHaptic)
                
                // Basic Info Section
                AddCustomGameBasicInfoSection(
                    gameName: $gameName,
                    gameURL: $gameURL,
                    selectedCategory: $selectedCategory
                )
                
                // Appearance Section
                AddCustomGameAppearanceSection(
                    selectedIcon: $selectedIcon,
                    selectedColor: $selectedColor,
                    showingIconPicker: $showingIconPicker,
                    showingColorPicker: $showingColorPicker
                )
                
                // Advanced Section
                AddCustomGameAdvancedSection(
                    resultPattern: $resultPattern,
                    exampleResult: $exampleResult,
                    showingPatternHelper: $showingPatternHelper,
                    selectedCategory: selectedCategory
                )
                
                // Preview Section
                AddCustomGamePreviewSection(
                    gameName: gameName,
                    selectedIcon: selectedIcon,
                    selectedColor: selectedColor,
                    selectedCategory: selectedCategory
                )
            }
            .padding()
        }
        .background(.regularMaterial)
        .navigationTitle("Add Custom Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    addGame()
                }
                .disabled(!isFormValid || isValidating)
                .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - Legacy Form Content (Simplified)
    private var legacyFormContent: some View {
        Form {
            Section("Basic Information") {
                TextField("Game Name", text: $gameName)
                TextField("Game URL", text: $gameURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(GameCategory.allCases.filter { $0 != .custom }, id: \.self) { category in
                        Label(category.displayName, systemImage: category.iconSystemName)
                            .tag(category)
                    }
                }
            }
            
            Section("Appearance") {
                HStack {
                    Label("Icon", systemImage: selectedIcon)
                    Spacer()
                    Button("Choose") {
                        showingIconPicker = true
                    }
                }
                
                HStack {
                    Label("Color", systemImage: "paintpalette")
                    Spacer()
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 30, height: 30)
                    Button("Choose") {
                        showingColorPicker = true
                    }
                }
            }
            
            Section("Advanced") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Result Pattern")
                        Spacer()
                        Button("Help") {
                            showingPatternHelper = true
                        }
                        .font(.caption)
                    }
                    
                    TextField("Regex pattern", text: $resultPattern)
                        .font(.system(.body, design: .monospaced))
                }
                
                TextField("Example Result", text: $exampleResult, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Add Custom Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    addGame()
                }
                .disabled(!isFormValid || isValidating)
                .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - Actions
    private func addGame() {
        // Validate inputs
        guard let url = URL(string: gameURL),
              url.isValidGameURL else {
            validationError = .invalidURL
            return
        }
        
        // Check for duplicate names
        let trimmedName = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        if appState.games.contains(where: { $0.displayName.lowercased() == trimmedName.lowercased() }) {
            validationError = .duplicateName
            return
        }
        
        // Create the custom game
        let customGame = Game(
            id: UUID(),
            name: trimmedName.lowercased().replacingOccurrences(of: " ", with: "_"),
            displayName: trimmedName,
            url: url,
            category: selectedCategory,
            resultPattern: resultPattern.isEmpty ? ".*" : resultPattern,
            iconSystemName: selectedIcon,
            backgroundColor: CodableColor(UIColor(selectedColor)),
            isPopular: false,
            isCustom: true
        )
        
        // Add to catalog and app state
        gameCatalog.addCustomGame(customGame)
        appState.games.append(customGame)
        
        // Haptic feedback
        HapticManager.shared.trigger(.buttonTap)
        showingSuccessHaptic = true
        
        // Dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    AddCustomGameView()
        .environment(GameCatalog())
        .environment(AppState())
}