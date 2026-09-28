//
//  GameResultDetailView+Supporting.swift
//  StreakSync
//
//  Supporting views for GameResultDetailView.
//

import SwiftUI

// MARK: - Quordle Detail Breakdown
struct QuordleDetailBreakdown: View {
    let result: GameResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill").foregroundStyle(.blue)
                Text("Puzzle Breakdown").font(.headline)
            }
            .padding(.bottom, 4)

            VStack(spacing: 12) {
                if let s1 = result.parsedData["score1"],
                   let s2 = result.parsedData["score2"],
                   let s3 = result.parsedData["score3"],
                   let s4 = result.parsedData["score4"] {
                    QuordlePuzzleRow(puzzleNumber: 1, score: s1, maxAttempts: result.maxAttempts)
                    QuordlePuzzleRow(puzzleNumber: 2, score: s2, maxAttempts: result.maxAttempts)
                    QuordlePuzzleRow(puzzleNumber: 3, score: s3, maxAttempts: result.maxAttempts)
                    QuordlePuzzleRow(puzzleNumber: 4, score: s4, maxAttempts: result.maxAttempts)
                }
            }

            Divider().padding(.vertical, 4)

            VStack(spacing: 8) {
                if let completedStr = result.parsedData["completedPuzzles"],
                   let completed = Int(completedStr) {
                    HStack {
                        Text("Success Rate").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(completed)/4 puzzles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(completed == 4 ? .green : (completed > 0 ? .orange : .red))
                    }

                    if completed > 0, let avgScore = calculateAverageScore() {
                        HStack {
                            Text("Average Attempts").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f/\(result.maxAttempts)", avgScore))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func calculateAverageScore() -> Double? {
        guard let s1 = result.parsedData["score1"],
              let s2 = result.parsedData["score2"],
              let s3 = result.parsedData["score3"],
              let s4 = result.parsedData["score4"] else { return nil }
        let validScores = [s1, s2, s3, s4].compactMap { $0 == "failed" ? nil : Int($0) }
        guard !validScores.isEmpty else { return nil }
        return Double(validScores.reduce(0, +)) / Double(validScores.count)
    }
}

struct QuordlePuzzleRow: View {
    let puzzleNumber: Int
    let score: String
    let maxAttempts: Int

    private var isCompleted: Bool { score != "failed" }
    private var displayScore: String { isCompleted ? "\(score)/\(maxAttempts)" : "Failed" }
    private var emoji: String {
        guard isCompleted, let s = Int(score) else { return "❌" }
        switch s {
        case 1...3: return "🟢"
        case 4...6: return "🟡"
        case 7...8: return "🟠"
        case 9: return "🔴"
        default: return "⚪️"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title3)
            Text("Puzzle \(puzzleNumber)").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(displayScore)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCompleted ? .green : .red)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(isCompleted ? Color.green.opacity(0.15) : Color.red.opacity(0.15)))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview("Game Result Detail") {
    GameResultDetailView(
        result: GameResult(
            gameId: UUID(),
            gameName: "Wordle",
            date: Date(),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 1,234 3/6\n\n⬛🟨⬛🟨⬛\n🟨⬛🟨⬛⬛\n🟩🟩🟩🟩🟩",
            parsedData: ["puzzleNumber": "1,234", "time": "2:34"]
        )
    )
    .environment(AppState())
}
