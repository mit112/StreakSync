//
//  GameResultDetailView+Supporting.swift
//  StreakSync
//
//  Supporting views for GameResultDetailView.
//

import SwiftUI

// MARK: - Supporting Views

struct ScoreBadge: View {
    let score: String
    let color: Color
    let revealed: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("Score:").font(.subheadline).foregroundStyle(.secondary)
            Text(score)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: score)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(color.opacity(0.1))
                .overlay { Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1) }
        }
        .scaleEffect(revealed ? 1 : 0.8)
        .opacity(revealed ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: revealed)
    }
}

struct DetailRowCompact: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image.safeSystemName(icon, fallback: "info.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body.weight(.medium))
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct DetailCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image.safeSystemName(icon, fallback: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, value: isHovered)
                Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                }
                .shadow(color: isHovered ? color.opacity(0.1) : .clear, radius: 8, x: 0, y: 4)
        }
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.2)) { isHovered = hovering }
        }
        .hoverEffect(.highlight)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
        }
        .padding()
    }
}

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
