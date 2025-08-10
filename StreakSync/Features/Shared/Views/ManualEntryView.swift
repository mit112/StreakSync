//
//  ManualEntryView.swift
//  StreakSync
//
//  Simplified manual entry with clean form design
//

import SwiftUI

// MARK: - Manual Entry View
struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var gameResult = ""
    @State private var selectedGame: Game?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Instructions section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Paste your game result below")
                            .font(.subheadline)
                    }
                }
                
                // Game selection
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
                Image(systemName: game.iconSystemName)
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
