//
//  ManualEntryView.swift
//  StreakSync
//
//  Simplified manual entry with clean form design
//

/*
 * MANUALENTRYVIEW - USER-FRIENDLY GAME RESULT INPUT SYSTEM
 * 
 * WHAT THIS FILE DOES:
 * This file creates a simple form where users can manually enter their game results when
 * they can't use the Share Extension. It's like a "backup input method" that allows users
 * to paste their game results (like "Wordle 1,492 3/6") and the app will automatically
 * parse and save them. Think of it as a "manual data entry form" that ensures users can
 * always add their results, even when the Share Extension doesn't work or isn't available.
 * 
 * WHY IT EXISTS:
 * Sometimes the Share Extension doesn't work perfectly, or users prefer to manually enter
 * their results. This view provides a clean, user-friendly way to input game results
 * manually. It includes helpful examples and validation to make sure users enter their
 * results correctly, and it uses the same parsing logic as the Share Extension to ensure
 * consistency.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides a fallback method for adding game results
 * - Ensures users can always add their results regardless of Share Extension issues
 * - Provides a clean, intuitive interface for manual data entry
 * - Includes helpful examples and validation for different games
 * - Uses the same parsing logic as the Share Extension for consistency
 * - Supports both pre-selected games and game selection
 * - Handles errors gracefully with user-friendly messages
 * 
 * WHAT IT REFERENCES:
 * - AppState: For accessing games and adding new results
 * - Game: The game being entered (can be pre-selected or chosen by user)
 * - GameResultParser: For parsing the entered text into structured data
 * - SwiftUI Form: For creating a clean, native iOS form interface
 * - TextEditor: For multi-line text input
 * - NavigationStack: For navigation and dismissal
 * 
 * WHAT REFERENCES IT:
 * - GameDetailView: Can navigate to this view for manual entry
 * - Dashboard: Can navigate to this view from game cards
 * - Settings: Can navigate to this view for data management
 * - NavigationCoordinator: Manages navigation to this view
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. USER EXPERIENCE IMPROVEMENTS:
 *    - The current form could be more intuitive
 *    - Add support for different input methods (voice, camera)
 *    - Implement smart suggestions and autocomplete
 *    - Add support for batch entry of multiple results
 * 
 * 2. VALIDATION IMPROVEMENTS:
 *    - The current validation is basic - could be more sophisticated
 *    - Add real-time validation as users type
 *    - Implement smart error correction and suggestions
 *    - Add support for different game formats and variations
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 4. PERFORMANCE OPTIMIZATIONS:
 *    - The current parsing could be optimized
 *    - Consider caching parsed results for better performance
 *    - Add support for background parsing
 *    - Implement efficient text processing
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for form logic
 *    - Test different input scenarios and edge cases
 *    - Add UI tests for form interactions
 *    - Test accessibility features
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for form features
 *    - Document the input formats and validation rules
 *    - Add examples of how to use different features
 *    - Create form flow diagrams
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new game types
 *    - Add support for custom input formats
 *    - Implement form templates
 *    - Add support for third-party integrations
 * 
 * 8. ERROR HANDLING:
 *    - The current error handling is basic - could be more robust
 *    - Add support for different error types and recovery
 *    - Implement user-friendly error messages
 *    - Add support for error reporting and feedback
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Forms: User interfaces for collecting and submitting data
 * - Text input: Allowing users to enter text data
 * - Validation: Checking that user input is correct and complete
 * - Parsing: Converting text into structured data that programs can understand
 * - Error handling: What to do when something goes wrong
 * - User experience: Making sure the app is easy and pleasant to use
 * - Accessibility: Making sure the app is usable for everyone
 * - Navigation: Moving between different screens in the app
 * - State management: Keeping track of what the user has entered
 * - Data binding: Connecting UI elements to data that can change
 */

import SwiftUI

// MARK: - Manual Entry View
struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var gameResult = ""
    @State private var selectedGame: Game?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Optional pre-selected game (e.g., when navigating from a specific game's detail page)
    private let preSelectedGame: Game?
    
    init(preSelectedGame: Game? = nil) {
        self.preSelectedGame = preSelectedGame
    }
    
    // MARK: - Computed Properties
    private var instructionText: String {
        if let preSelectedGame = preSelectedGame {
            return "Paste your \(preSelectedGame.displayName) result below"
        } else {
            return "Paste your game result below"
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Instructions section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text(instructionText)
                            .font(.subheadline)
                    }
                }
                
                // Game selection (only show if no game is pre-selected)
                if preSelectedGame == nil {
                    Section("Select Game") {
                        ForEach(appState.games.filter(\.isPopular)) { game in
                            GameSelectionRow(
                                game: game,
                                isSelected: selectedGame?.id == game.id
                            ) {
                                selectedGame = game
                            }
                        }
                    }
                }
                
                // Result entry
                Section("Game Result") {
                    TextEditor(text: $gameResult)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .overlay(
                            Group {
                                if gameResult.isEmpty {
                                    Text("Paste your result here...")
                                        .foregroundStyle(.tertiary)
                                        .allowsHitTesting(false)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                            }
                        )
                }
                
                // Example section
                if let game = selectedGame {
                    Section("Example") {
                        Text(exampleText(for: game))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveResult()
                    }
                    .disabled(gameResult.isEmpty || selectedGame == nil)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Pre-select the game if provided
            if let preSelectedGame = preSelectedGame {
                selectedGame = preSelectedGame
            }
        }
    }
    
    // MARK: - Private Methods
    private func exampleText(for game: Game) -> String {
        switch game.name {
        case "wordle":
            return "Wordle 942 3/6\n\n⬛🟨⬛🟨⬛\n🟨⬛🟨⬛⬛\n🟩🟩🟩🟩🟩"
        case "quordle":
            return "Daily Quordle 723\n4️⃣5️⃣\n6️⃣7️⃣"
        case "nerdle":
            return "nerdlegame 728 3/6\n\n🟪⬛🟪🟪⬛🟪⬛⬛\n🟪🟩🟩🟩⬛🟩⬛🟪\n🟩🟩🟩🟩🟩🟩🟩🟩"
        default:
            return "Paste your \(game.displayName) result"
        }
    }
    
    private func saveResult() {
        guard let game = selectedGame else { return }
        
        // Create game result from manual entry
        let parser = GameResultParser()
        
        do {
            let result = try parser.parse(gameResult, for: game)
            appState.addGameResult(result)
            dismiss()
        } catch {
            errorMessage = "Could not parse the result. Please check the format and try again."
            showingError = true
        }
    }
}

// MARK: - Game Selection Row
struct GameSelectionRow: View {
    let game: Game
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                    .font(.title3)
                    .foregroundStyle(game.backgroundColor.color)
                    .frame(width: 30, height: 30)
                
                Text(game.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ManualEntryView()
        .environment(AppState())
}
