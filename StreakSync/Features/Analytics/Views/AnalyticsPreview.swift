//
//  AnalyticsPreview.swift
//  StreakSync
//
//  Preview for analytics dashboard
//

import SwiftUI

// MARK: - Analytics Preview
struct AnalyticsPreview: View {
    @State private var appState = AppState()
    @State private var analyticsService: AnalyticsService
    
    init() {
        let appState = AppState()
        self._appState = State(wrappedValue: appState)
        self._analyticsService = State(wrappedValue: AnalyticsService(appState: appState))
    }
    
    var body: some View {
        NavigationStack {
            AnalyticsDashboardView(analyticsService: analyticsService)
        }
        .onAppear {
            // Add some sample data for preview
            Task {
                await addSampleData()
            }
        }
    }
    
    private func addSampleData() async {
        // Add sample games and streaks for preview
        let sampleGames = [
            Game(
                name: "wordle",
                displayName: "Wordle",
                url: URL(string: "https://www.nytimes.com/games/wordle")!,
                category: .word,
                resultPattern: "Wordle",
                iconSystemName: "textformat.abc",
                backgroundColor: CodableColor(.green),
                isPopular: true,
                isCustom: false
            ),
            Game(
                name: "connections",
                displayName: "Connections",
                url: URL(string: "https://www.nytimes.com/games/connections")!,
                category: .word,
                resultPattern: "Connections",
                iconSystemName: "link",
                backgroundColor: CodableColor(.purple),
                isPopular: true,
                isCustom: false
            )
        ]
        
        // Add sample streaks
        let sampleStreaks = [
            GameStreak(
                gameId: sampleGames[0].id,
                gameName: sampleGames[0].displayName,
                currentStreak: 5,
                maxStreak: 12,
                totalGamesPlayed: 25,
                totalGamesCompleted: 20,
                lastPlayedDate: Date(),
                streakStartDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())
            ),
            GameStreak(
                gameId: sampleGames[1].id,
                gameName: sampleGames[1].displayName,
                currentStreak: 3,
                maxStreak: 8,
                totalGamesPlayed: 15,
                totalGamesCompleted: 12,
                lastPlayedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                streakStartDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())
            )
        ]
        
        // Add sample results
        let sampleResults = [
            GameResult(
                gameId: sampleGames[0].id,
                gameName: sampleGames[0].displayName,
                date: Date(),
                score: 3,
                maxAttempts: 6,
                completed: true,
                sharedText: "Wordle 123 3/6"
            ),
            GameResult(
                gameId: sampleGames[1].id,
                gameName: sampleGames[1].displayName,
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                score: 4,
                maxAttempts: 4,
                completed: true,
                sharedText: "Connections 123 4/4"
            )
        ]
        
        await MainActor.run {
            appState.games = sampleGames
            appState.streaks = sampleStreaks
            appState.recentResults = sampleResults
        }
    }
}

#Preview {
    AnalyticsPreview()
}
