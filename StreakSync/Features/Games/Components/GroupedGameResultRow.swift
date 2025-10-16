//
//  GroupedGameResultRow.swift
//  StreakSync
//
//  Grouped result row for games like Pips that have multiple difficulties per puzzle
//

import SwiftUI

struct GroupedGameResultRow: View {
    let groupedResult: GroupedGameResult
    var onDelete: (() -> Void)? = nil
    @State private var showingDetail = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Main row
            Button {
                HapticManager.shared.trigger(.toggleSwitch)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(groupedResult.displayTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 8) {
                            Text(groupedResult.completionStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let bestTime = groupedResult.bestTime {
                                Text("• \(bestTime)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Difficulty indicators
                    HStack(spacing: 4) {
                        if groupedResult.hasEasy {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                        }
                        if groupedResult.hasMedium {
                            Circle()
                                .fill(.yellow)
                                .frame(width: 8, height: 8)
                        }
                        if groupedResult.hasHard {
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            
            // Expanded details - Ultra simple approach
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(Array(groupedResult.results.enumerated()), id: \.element.id) { index, result in
                        DifficultyResultRow(result: result, onDelete: onDelete)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
                .onAppear {
                    print("🔍 GroupedGameResultRow: Expanded with \(groupedResult.results.count) results")
                    for (index, result) in groupedResult.results.enumerated() {
                        print("   \(index + 1). \(result.parsedData["difficulty"] ?? "?") - \(result.parsedData["time"] ?? "?")")
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete All", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Individual Difficulty Result Row
struct DifficultyResultRow: View {
    let result: GameResult
    var onDelete: (() -> Void)? = nil
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            HapticManager.shared.trigger(.toggleSwitch)
            showingDetail = true
        } label: {
            HStack {
                // Difficulty indicator
                Circle()
                    .fill(difficultyColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.displayScore)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    Text(result.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            GameResultDetailView(result: result, onDelete: onDelete)
        }
    }
    
    private var difficultyColor: Color {
        guard let difficulty = result.parsedData["difficulty"] else { return .gray }
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .yellow
        case "hard": return .orange
        default: return .gray
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        GroupedGameResultRow(
            groupedResult: GroupedGameResult(
                gameId: Game.pips.id,
                gameName: "pips",
                puzzleNumber: "46",
                date: Date(),
                results: [
                    GameResult(
                        gameId: Game.pips.id,
                        gameName: "pips",
                        date: Date(),
                        score: 1,
                        maxAttempts: 3,
                        completed: true,
                        sharedText: "Pips #46 Easy 🟢\n1:03",
                        parsedData: [
                            "puzzleNumber": "46",
                            "difficulty": "Easy",
                            "time": "1:03",
                            "totalSeconds": "63"
                        ]
                    ),
                    GameResult(
                        gameId: Game.pips.id,
                        gameName: "pips",
                        date: Date(),
                        score: 2,
                        maxAttempts: 3,
                        completed: true,
                        sharedText: "Pips #46 Medium 🟡\n0:54",
                        parsedData: [
                            "puzzleNumber": "46",
                            "difficulty": "Medium",
                            "time": "0:54",
                            "totalSeconds": "54"
                        ]
                    ),
                    GameResult(
                        gameId: Game.pips.id,
                        gameName: "pips",
                        date: Date(),
                        score: 3,
                        maxAttempts: 3,
                        completed: true,
                        sharedText: "Pips #46 Hard 🟠\n2:59",
                        parsedData: [
                            "puzzleNumber": "46",
                            "difficulty": "Hard",
                            "time": "2:59",
                            "totalSeconds": "179"
                        ]
                    )
                ]
            )
        )
        
        GroupedGameResultRow(
            groupedResult: GroupedGameResult(
                gameId: Game.pips.id,
                gameName: "pips",
                puzzleNumber: "45",
                date: Date().addingTimeInterval(-86400),
                results: [
                    GameResult(
                        gameId: Game.pips.id,
                        gameName: "pips",
                        date: Date().addingTimeInterval(-86400),
                        score: 3,
                        maxAttempts: 3,
                        completed: true,
                        sharedText: "Pips #45 Hard 🟠\n2:59",
                        parsedData: [
                            "puzzleNumber": "45",
                            "difficulty": "Hard",
                            "time": "2:59",
                            "totalSeconds": "179"
                        ]
                    )
                ]
            )
        )
    }
    .padding()
    .background(.black)
}