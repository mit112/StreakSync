//
//  AddCustomGameView.swift
//  StreakSync
//
//  Custom game addition with iOS 26 materials and comprehensive validation
//  REFACTORED: Extracted components for better organization
//

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
            iOS26FormContent
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