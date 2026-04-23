//
//  DebugDataSeederView.swift
//  StreakSync
//
//  Debug-only live data seeder — adds realistic results one at a time so streaks,
//  achievements, and UI all update as if real users were playing.
//

#if DEBUG

import SwiftUI

@MainActor
struct DebugDataSeederView: View {
    @Environment(AppState.self) private var appState

    @State private var isSeeding = false
    @State private var addedCount = 0
    @State private var failedCount = 0
    @State private var totalCount = 0
    @State private var currentGame = ""
    @State private var seedTask: Task<Void, Never>?

    var body: some View {
        List {
            Section("Current State") {
                LabeledContent("Game Results") {
                    Text("\(appState.recentResults.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Active Streaks") {
                    Text("\(appState.streaks.filter { $0.currentStreak > 0 }.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Achievements Unlocked") {
                    Text("\(appState.tieredAchievements.filter { $0.isUnlocked }.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if isSeeding {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(currentGame)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(addedCount) / \(totalCount)")
                                .monospacedDigit()
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(addedCount), total: Double(max(1, totalCount)))
                    }
                    .padding(.vertical, 4)

                    Button("Cancel", role: .destructive) {
                        seedTask?.cancel()
                        isSeeding = false
                    }
                } else {
                    Button("Seed 60 Days of Data") {
                        startSeeding()
                    }

                    if addedCount > 0 {
                        Label(
                            "\(addedCount) added, \(failedCount) skipped (duplicates)",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                        .font(.caption)
                    }
                }
            } header: {
                Text("Seed Data")
            } footer: {
                Text(
                    "Results are inserted through the normal addGameResult path — streaks and " +
                    "achievements update live. Covers Wordle, Connections, Mini Crossword, " +
                    "Spelling Bee, Nerdle, Strands, Quordle, Pinpoint, Queens, Octordle, " +
                    "Pips, Tango, Crossclimb, Zip, and Mini Sudoku. " +
                    "Run again to skip already-added puzzles."
                )
            }

            Section("Cleanup") {
                Text("Settings → Data & Privacy → Delete All Data removes all seeded results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Debug Seeder")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startSeeding() {
        let results = DebugSeedData.buildResults()
        totalCount = results.count
        addedCount = 0
        failedCount = 0
        isSeeding = true

        seedTask = Task {
            for result in results {
                guard !Task.isCancelled else { break }
                currentGame = result.gameName
                if appState.addGameResult(result) {
                    addedCount += 1
                } else {
                    failedCount += 1
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
            isSeeding = false
        }
    }
}

// MARK: - Seed Data Builder

private enum DebugSeedData {
    private static let calendar = Calendar.current

    static func buildResults() -> [GameResult] {
        let today = calendar.startOfDay(for: Date())
        var results: [GameResult] = []

        results += wordleResults(from: today, count: 60)
        results += connectionsResults(from: today, count: 60)
        results += miniCrosswordResults(from: today, count: 30)
        results += spellingBeeResults(from: today, count: 25)
        results += nerdleResults(from: today, count: 20)
        results += strandsResults(from: today, count: 20)
        results += quordleResults(from: today)
        results += pinpointResults(from: today)
        results += queensResults(from: today)
        results += octordleResults(from: today)
        results += pipsResults(from: today)
        results += tangoResults(from: today)
        results += crossclimbResults(from: today)
        results += zipResults(from: today)
        results += miniSudokuResults(from: today)

        // Oldest first so streak logic increments correctly
        return results.sorted { $0.date < $1.date }
    }

    private static func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return minutes > 0 ? String(format: "%d:%02d", minutes, seconds) : "\(seconds)s"
    }

    private static func ago(_ days: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: -days, to: today) ?? today
    }

    // Wordle — 60 consecutive days, 1 perfect score to trigger Perfectionist
    private static func wordleResults(from today: Date, count: Int) -> [GameResult] {
        let scores = [3,4,5,3,2,4,6,3,4,3,5,3,4,3,3,5,4,3,4,2,
                      3,4,5,3,4,3,4,5,3,4,3,4,3,5,3,2,4,3,4,3,
                      5,3,4,3,4,3,2,4,3,5,3,4,3,4,3,4,5,1,3,4]
        return (0..<count).map { offset in
            let puzzle = 1100 + offset
            let score = scores[offset % scores.count]
            return GameResult(
                gameId: Game.wordle.id, gameName: Game.wordle.name,
                date: ago(offset, from: today),
                score: score, maxAttempts: 6, completed: true,
                sharedText: "Wordle \(puzzle) \(score)/6",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // Connections — 60 consecutive days
    private static func connectionsResults(from today: Date, count: Int) -> [GameResult] {
        let scores = [4,4,4,3,4,4,3,4,4,4]
        return (0..<count).map { offset in
            let puzzle = 500 + offset
            return GameResult(
                gameId: Game.connections.id, gameName: Game.connections.name,
                date: ago(offset, from: today),
                score: scores[offset % scores.count], maxAttempts: 4, completed: true,
                sharedText: "Connections Puzzle #\(puzzle)\n🟩🟨🟦🟪",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // Mini Crossword — 30 days (time in seconds)
    private static func miniCrosswordResults(from today: Date, count: Int) -> [GameResult] {
        let times = [95,88,120,75,110,65,140,90,80,105,95,70,130,85,100,
                     75,95,88,110,60,95,85,100,75,90,110,65,95,80,105]
        return (0..<count).map { offset in
            let puzzle = 800 + offset
            let time = times[offset % times.count]
            return GameResult(
                gameId: Game.miniCrossword.id, gameName: Game.miniCrossword.name,
                date: ago(offset, from: today),
                score: time, maxAttempts: 0, completed: true,
                sharedText: "Mini Crossword \(time)s",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // Spelling Bee — 25 days (point totals)
    private static func spellingBeeResults(from today: Date, count: Int) -> [GameResult] {
        let pts = [125,89,142,98,175,110,63,145,88,120,95,155,78,132,105,
                   88,160,92,115,140,85,108,145,72,130]
        return (0..<count).map { offset in
            let puzzle = 900 + offset
            let score = pts[offset % pts.count]
            return GameResult(
                gameId: Game.spellingBee.id, gameName: Game.spellingBee.name,
                date: ago(offset, from: today),
                score: score, maxAttempts: 0, completed: true,
                sharedText: "Spelling Bee \(score) pts",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // Nerdle — 20 days
    private static func nerdleResults(from today: Date, count: Int) -> [GameResult] {
        let scores = [2,3,4,3,5,2,4,3,3,4,2,5,3,4,3,3,4,2,3,5]
        return (0..<count).map { offset in
            let puzzle = 700 + offset
            let score = scores[offset]
            return GameResult(
                gameId: Game.nerdle.id, gameName: Game.nerdle.name,
                date: ago(offset, from: today),
                score: score, maxAttempts: 6, completed: true,
                sharedText: "nerdlegame \(puzzle) \(score)/6",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // Strands — 20 days (hint count, lower is better)
    private static func strandsResults(from today: Date, count: Int) -> [GameResult] {
        let hints = [0,1,0,2,0,1,0,0,1,0,2,0,1,0,0,1,0,2,0,1]
        return (0..<count).map { offset in
            let puzzle = 300 + offset
            return GameResult(
                gameId: Game.strands.id, gameName: Game.strands.name,
                date: ago(offset, from: today),
                score: hints[offset], maxAttempts: 3, completed: true,
                sharedText: "Strands #\(puzzle)",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // Quordle — every other day, 15 results
    private static func quordleResults(from today: Date) -> [GameResult] {
        let scores = [5,7,6,8,5,7,6,7,5,6,8,5,7,6,5]
        return (0..<15).map { i in
            let puzzle = 400 + i
            return GameResult(
                gameId: Game.quordle.id, gameName: Game.quordle.name,
                date: ago(i * 2 + 1, from: today),
                score: scores[i], maxAttempts: 9, completed: true,
                sharedText: "Daily Quordle \(puzzle)",
                parsedData: ["puzzleNumber": "\(puzzle)", "mode": "daily"]
            )
        }
    }

    // LinkedIn Pinpoint — every 3rd day, 15 results
    private static func pinpointResults(from today: Date) -> [GameResult] {
        let scores = [1,2,1,3,1,2,1,2,1,1,2,3,1,2,1]
        return (0..<15).map { i in
            let puzzle = 600 + i
            return GameResult(
                gameId: Game.linkedinPinpoint.id, gameName: Game.linkedinPinpoint.name,
                date: ago(i * 3, from: today),
                score: scores[i], maxAttempts: 5, completed: true,
                sharedText: "Pinpoint puzzle \(scores[i])/5",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // LinkedIn Queens — every 5th day offset by 2, 10 results
    private static func queensResults(from today: Date) -> [GameResult] {
        let times = [45,72,38,90,55,41,68,33,85,60]
        return (0..<10).map { i in
            let puzzle = 200 + i
            return GameResult(
                gameId: Game.linkedinQueens.id, gameName: Game.linkedinQueens.name,
                date: ago(i * 5 + 2, from: today),
                score: times[i], maxAttempts: 0, completed: true,
                sharedText: "Queens puzzle \(times[i])s",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // Octordle — weekly, 8 results
    private static func octordleResults(from today: Date) -> [GameResult] {
        let scores = [9,11,10,12,9,10,11,10]
        return (0..<8).map { i in
            let puzzle = 100 + i
            return GameResult(
                gameId: Game.octordle.id, gameName: Game.octordle.name,
                date: ago(i * 7 + 3, from: today),
                score: scores[i], maxAttempts: 13, completed: true,
                sharedText: "Daily Octordle #\(puzzle)",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // Pips — 15 results cycling Easy / Medium / Hard, every 3rd day
    private static func pipsResults(from today: Date) -> [GameResult] {
        let entries: [(Int, String)] = [
            (45, "Easy"), (110, "Medium"), (185, "Hard"),
            (38, "Easy"),  (95, "Medium"), (210, "Hard"),
            (52, "Easy"), (130, "Medium"), (170, "Hard"),
            (41, "Easy"),  (88, "Medium"), (195, "Hard"),
            (60, "Easy"), (120, "Medium"), (160, "Hard")
        ]
        return (0..<15).map { i in
            let puzzle = 150 + i
            let (seconds, difficulty) = entries[i]
            return GameResult(
                gameId: Game.pips.id, gameName: Game.pips.name,
                date: ago(i * 3 + 1, from: today),
                score: seconds, maxAttempts: 0, completed: true,
                sharedText: "Pips #\(puzzle) \(difficulty)",
                parsedData: [
                    "puzzleNumber": "\(puzzle)",
                    "difficulty": difficulty,
                    "time": formatTime(seconds),
                    "totalSeconds": "\(seconds)"
                ]
            )
        }
    }

    // LinkedIn Tango — every 4th day offset by 2, 12 results
    private static func tangoResults(from today: Date) -> [GameResult] {
        let times = [45,72,88,55,110,63,95,42,78,130,58,85]
        return (0..<12).map { i in
            let puzzle = 350 + i
            return GameResult(
                gameId: Game.linkedinTango.id, gameName: Game.linkedinTango.name,
                date: ago(i * 4 + 2, from: today),
                score: times[i], maxAttempts: 0, completed: true,
                sharedText: "Tango puzzle \(times[i])s",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // LinkedIn Crossclimb — every 4th day offset by 1, 12 results
    private static func crossclimbResults(from today: Date) -> [GameResult] {
        let times = [90,145,65,180,75,120,55,160,95,110,70,135]
        return (0..<12).map { i in
            let puzzle = 450 + i
            return GameResult(
                gameId: Game.linkedinCrossclimb.id, gameName: Game.linkedinCrossclimb.name,
                date: ago(i * 4 + 1, from: today),
                score: times[i], maxAttempts: 0, completed: true,
                sharedText: "Crossclimb puzzle \(times[i])s",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // LinkedIn Zip — every 5th day offset by 3, 10 results
    private static func zipResults(from today: Date) -> [GameResult] {
        let times = [30,48,65,38,55,42,70,35,60,45]
        return (0..<10).map { i in
            let puzzle = 550 + i
            return GameResult(
                gameId: Game.linkedinZip.id, gameName: Game.linkedinZip.name,
                date: ago(i * 5 + 3, from: today),
                score: times[i], maxAttempts: 0, completed: true,
                sharedText: "Zip puzzle \(times[i])s",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }

    // LinkedIn Mini Sudoku — weekly, 8 results
    // scoringModel is higherIsBetter; score=1 = completed (no time in real share format)
    private static func miniSudokuResults(from today: Date) -> [GameResult] {
        return (0..<8).map { i in
            let puzzle = 650 + i
            return GameResult(
                gameId: Game.linkedinMiniSudoku.id, gameName: Game.linkedinMiniSudoku.name,
                date: ago(i * 7 + 4, from: today),
                score: 1, maxAttempts: 0, completed: true,
                sharedText: "Mini Sudoku puzzle completed",
                parsedData: ["puzzleNumber": "\(puzzle)"]
            )
        }
    }
}

#endif
