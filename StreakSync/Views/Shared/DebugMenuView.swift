//
//  DebugMenuView.swift
//  StreakSync
//
//  Created by MiT on 7/29/25.
//

//
//  DebugMenuView.swift
//  StreakSync
//
//  Debug menu for development - only available in DEBUG builds
//

#if DEBUG
import SwiftUI

struct DebugMenuView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingClearAlert = false
    @State private var showingAddTestDataAlert = false
    @State private var testResultText = ""
    @State private var selectedTestGame = Game.wordle
    
    var body: some View {
        NavigationStack {
            List {
                // Data Management Section
                Section("Data Management") {
                    Button("Add Test Data") {
                        showingAddTestDataAlert = true
                    }
                    
                    Button("Clear All Data", role: .destructive) {
                        showingClearAlert = true
                    }
                    
                    Button("Force Refresh") {
                        Task {
                            await container.appState.refreshData()
                        }
                    }
                }
                
                // Share Extension Testing
                Section("Share Extension Testing") {
                    Button("Simulate Wordle Result") {
                        simulateGameResult(for: .wordle)
                    }
                    
                    Button("Simulate Quordle Result") {
                        simulateGameResult(for: .quordle)
                    }
                    
                    Button("Simulate Nerdle Result") {
                        simulateGameResult(for: .nerdle)
                    }
                    
                    Button("Check App Group Access") {
                        checkAppGroupAccess()
                    }
                }
                
                // Navigation Testing
                Section("Navigation Testing") {
                    Button("Test Deep Link - Game") {
                        testGameDeepLink()
                    }
                    
                    Button("Test Deep Link - Achievement") {
                        testAchievementDeepLink()
                    }
                    
                    Button("Show Random Error") {
                        showRandomError()
                    }
                }
                
                // State Inspection
                Section("Current State") {
                    LabeledContent("Total Games", value: "\(container.appState.games.count)")
                    LabeledContent("Active Streaks", value: "\(container.appState.totalActiveStreaks)")
                    LabeledContent("Recent Results", value: "\(container.appState.recentResults.count)")
                    LabeledContent("Achievements", value: "\(container.appState.unlockedAchievements.count)/\(container.appState.achievements.count)")
                    LabeledContent("Data Loaded", value: container.appState.isDataLoaded ? "Yes" : "No")
                }
                
                // Theme Testing
                Section("Theme Testing") {
                    ForEach(ColorTheme.allCases, id: \.self) { theme in
                        Button(theme.rawValue) {
                            container.themeManager.setTheme(theme)
                        }
                    }
                    
                    Button(container.themeManager.useTimeBasedThemes ? "Disable Time-based Themes" : "Enable Time-based Themes") {
                            if container.themeManager.useTimeBasedThemes {
                                container.themeManager.useTimeBasedThemes = false
                            } else {
                                container.themeManager.enableTimeBasedThemes()
                            }
                        }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Add Test Data", isPresented: $showingAddTestDataAlert) {
            Button("Add 5 Games") {
                addTestGames(count: 5)
            }
            Button("Add 20 Games") {
                addTestGames(count: 20)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Add random test game results?")
        }
        .alert("Clear All Data?", isPresented: $showingClearAlert) {
            Button("Clear", role: .destructive) {
                Task {
                    await container.appState.clearAllData()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all streaks, achievements, and game data.")
        }
    }
    
    // MARK: - Test Actions
    
    private func simulateGameResult(for game: Game) {
        let puzzleNumber = Int.random(in: 900...999)
        let score = Int.random(in: 1...6)
        let completed = score <= game.maxAttempts
        
        let result = GameResult(
            gameId: game.id,
            gameName: game.name,
            date: Date(),
            score: completed ? score : nil,
            maxAttempts: game.maxAttempts,
            completed: completed,
            sharedText: generateTestShareText(for: game, puzzle: puzzleNumber, score: score),
            parsedData: ["puzzleNumber": "\(puzzleNumber)", "source": "debug"]
        )
        
        container.appState.addGameResult(result)
        HapticManager.shared.trigger(.streakUpdate)
    }
    
    private func generateTestShareText(for game: Game, puzzle: Int, score: Int) -> String {
        switch game.name {
        case "wordle":
            return "Wordle \(puzzle) \(score)/6\n\n⬛🟨⬛🟨⬛\n🟨⬛🟨⬛⬛\n🟩🟩🟩🟩🟩"
        case "quordle":
            return "Daily Quordle \(puzzle)\n4️⃣5️⃣\n6️⃣7️⃣"
        case "nerdle":
            return "nerdlegame \(puzzle) \(score)/6\n\n🟪⬛🟪🟪⬛🟪⬛⬛"
        default:
            return "\(game.displayName) \(puzzle) \(score)/6"
        }
    }
    
    private func addTestGames(count: Int) {
        let games = [Game.wordle, Game.quordle, Game.nerdle, Game.heardle]
        
        for i in 0..<count {
            let game = games.randomElement()!
            let daysAgo = Int.random(in: 0...30)
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
            let score = Int.random(in: 1...6)
            let completed = Bool.random()
            
            let result = GameResult(
                gameId: game.id,
                gameName: game.name,
                date: date,
                score: completed ? score : nil,
                maxAttempts: 6,
                completed: completed,
                sharedText: "Test result \(i)",
                parsedData: ["puzzleNumber": "\(900 + i)", "source": "debug"]
            )
            
            container.appState.addGameResult(result)
        }
    }
    
    private func checkAppGroupAccess() {
        let appGroupID = "group.com.mitsheth.StreakSync"
        
        if let userDefaults = UserDefaults(suiteName: appGroupID) {
            // Try to write and read
            let testKey = "debugTest"
            let testValue = UUID().uuidString
            userDefaults.set(testValue, forKey: testKey)
            
            if let readValue = userDefaults.string(forKey: testKey), readValue == testValue {
                container.appState.setError("✅ App Group access working correctly")
            } else {
                container.appState.setError("❌ App Group read/write failed")
            }
            
            userDefaults.removeObject(forKey: testKey)
        } else {
            container.appState.setError("❌ Cannot access App Group: \(appGroupID)")
        }
    }
    
    private func testGameDeepLink() {
        let game = Game.wordle
        NotificationCenter.default.post(
            name: .openGameRequested,
            object: ["name": game.name, "id": game.id.uuidString]
        )
        dismiss()
    }
    
    private func testAchievementDeepLink() {
        if let achievement = container.appState.achievements.first {
            NotificationCenter.default.post(
                name: .openAchievementRequested,
                object: achievement.id.uuidString
            )
            dismiss()
        }
    }
    
    private func showRandomError() {
        let errors: [AppError] = [
            .shareExtension(.processingTimeout),
            .parsing(.unknownGameFormat(text: "Test text")),
            .persistence(.saveFailed(dataType: "test", underlying: nil)),
            .sync(.syncTimeout),
            .ui(.navigationFailed(destination: "test"))
        ]
        
        if let randomError = errors.randomElement() {
            container.appState.setError(randomError)
        }
    }
}

// MARK: - Game Extension for Debug
private extension Game {
    var maxAttempts: Int {
        switch name {
        case "wordle", "nerdle", "heardle": return 6
        case "quordle": return 9
        default: return 6
        }
    }
}

#endif
