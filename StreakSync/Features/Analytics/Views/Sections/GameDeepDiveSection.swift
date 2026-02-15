//
//  GameDeepDiveSection.swift
//  StreakSync
//
//  Game-specific analytics deep dives (Wordle, Pips, Pinpoint, Strands).
//

import SwiftUI

// MARK: - Game Deep Dive
struct GameDeepDiveSection: View {
    let gameAnalytics: GameAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deep Dive")
                .font(.headline)
                .fontWeight(.semibold)

            switch gameAnalytics.game.name.lowercased() {
            case "wordle", "nerdle":
                WordleDeepDive(results: gameAnalytics.recentResults)
            case "pips":
                PipsDeepDive(results: gameAnalytics.recentResults)
            case "linkedinpinpoint":
                PinpointDeepDive(results: gameAnalytics.recentResults)
            case "strands":
                StrandsDeepDive(results: gameAnalytics.recentResults)
            default:
                EmptyView()
            }
        }
        .padding()
        .cardStyle()
    }
}

// MARK: - Deep Dive Views

private struct WordleDeepDive: View {
    let results: [GameResult]

    private var guessDistribution: [Int: Int] {
        var dist: [Int: Int] = [:]
        for r in results { if let s = r.score { dist[s, default: 0] += 1 } }
        return dist
    }
    private var failRate: Double {
        let total = results.count
        guard total > 0 else { return 0 }
        return Double(results.filter { !$0.completed }.count) / Double(total)
    }
    private var averageGuesses: Double {
        let guesses = results.compactMap { $0.score }
        guard !guesses.isEmpty else { return 0 }
        return Double(guesses.reduce(0, +)) / Double(guesses.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "Fail rate: %.0f%%", failRate * 100)).font(.caption)
            Text(String(format: "Average guesses: %.2f", averageGuesses)).font(.caption)
            HStack(spacing: 6) {
                ForEach((1...6), id: \.self) { g in
                    let count = guessDistribution[g] ?? 0
                    VStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.green)
                            .frame(width: 18, height: CGFloat(max(1, count)) * 6)
                        Text("\(g)").font(.caption2)
                    }
                }
            }
        }
    }
}

private struct PipsDeepDive: View {
    let results: [GameResult]

    private var easyTimes: [Int] { results.filter { $0.parsedData["difficulty"] == "Easy" }.compactMap { Int($0.parsedData["totalSeconds"] ?? "") } }
    private var mediumTimes: [Int] { results.filter { $0.parsedData["difficulty"] == "Medium" }.compactMap { Int($0.parsedData["totalSeconds"] ?? "") } }
    private var hardTimes: [Int] { results.filter { $0.parsedData["difficulty"] == "Hard" }.compactMap { Int($0.parsedData["totalSeconds"] ?? "") } }

    private func format(_ seconds: Int?) -> String {
        guard let s = seconds else { return "—" }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
    private func avg(_ arr: [Int]) -> Int? { guard !arr.isEmpty else { return nil }; return arr.reduce(0, +) / arr.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Easy Best: \(format(easyTimes.min()))  Avg: \(format(avg(easyTimes)))").font(.caption)
            Text("Medium Best: \(format(mediumTimes.min()))  Avg: \(format(avg(mediumTimes)))").font(.caption)
            Text("Hard Best: \(format(hardTimes.min()))  Avg: \(format(avg(hardTimes)))").font(.caption)
        }
    }
}

private struct PinpointDeepDive: View {
    let results: [GameResult]
    private var guessDistribution: [Int: Int] {
        var d: [Int: Int] = [:]
        for r in results { if let s = r.score { d[s, default: 0] += 1 } }
        return d
    }
    var body: some View {
        HStack(spacing: 6) {
            ForEach((1...5), id: \.self) { g in
                let count = guessDistribution[g] ?? 0
                VStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.blue)
                        .frame(width: 18, height: CGFloat(max(1, count)) * 6)
                    Text("\(g)").font(.caption2)
                }
            }
        }
    }
}

private struct StrandsDeepDive: View {
    let results: [GameResult]
    private var hintsDistribution: [Int: Int] {
        var d: [Int: Int] = [:]
        for r in results { if let s = r.score { d[s, default: 0] += 1 } }
        return d
    }
    var body: some View {
        HStack(spacing: 6) {
            ForEach((0...10), id: \.self) { h in
                let count = hintsDistribution[h] ?? 0
                VStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.purple)
                        .frame(width: 12, height: CGFloat(max(1, count)) * 6)
                    Text("\(h)").font(.caption2)
                }
            }
        }
    }
}
