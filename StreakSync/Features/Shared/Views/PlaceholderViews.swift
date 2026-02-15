//
//  DetailViews.swift
//  StreakSync
//
//  Simplified detail views for game results and achievements
//

import SwiftUI

//// MARK: - Game Result Detail View
//struct GameResultDetailView: View {
//    let result: GameResult
//    @Environment(\.dismiss) private var dismiss
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: Spacing.xxl) {
//                    // Score display
//                    VStack(spacing: Spacing.md) {
//                        Text(result.scoreEmoji)
//                            .font(.system(size: 72))
//                        
//                        Text(result.gameName.capitalized)
//                            .font(.title3.weight(.medium))
//                        
//                        Text(result.displayScore)
//                            .font(.headline)
//                            .foregroundStyle(.secondary)
//                    }
//                    .padding(.top, Spacing.xl)
//                    
//                    // Details
//                    VStack(spacing: 0) {
//                        DetailRow(label: "Date", value: result.date.formatted(date: .abbreviated, time: .omitted))
//                        Divider()
//                        DetailRow(label: "Status", value: result.completed ? "Completed" : "Not Completed")
//                        Divider()
//                        DetailRow(label: "Attempts", value: result.displayScore)
//                        
//                        if let puzzleNumber = result.parsedData["puzzleNumber"] {
//                            Divider()
//                            DetailRow(label: "Puzzle", value: "#\(puzzleNumber)")
//                        }
//                    }
//                    .background(Color(.secondarySystemBackground))
//                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
//                    
//                    // Share button
//                    ShareLink(item: result.sharedText) {
//                        Label("Share Result", systemImage: "square.and.arrow.up")
//                            .frame(maxWidth: .infinity)
//                    }
//                    .buttonStyle(.borderedProminent)
//                }
//                .padding()
//            }
//            .navigationTitle("Game Result")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button("Done") {
//                        dismiss()
//                    }
//                }
//            }
//        }
//        .presentationDetents([.medium])
//    }
//}

// MARK: - Detail Row Helper
//struct DetailRow: View {
//    let label: String
//    let value: String
//    
//    var body: some View {
//        HStack {
//            Text(label)
//                .font(.subheadline)
//                .foregroundStyle(.secondary)
//            
//            Spacer()
//            
//            Text(value)
//                .font(.subheadline)
//        }
//        .padding()
//    }
//}

// MARK: - Preview
#Preview("Game Result Detail") {
    GameResultDetailView(
        result: GameResult(
            gameId: UUID(),
            gameName: "wordle",
            date: Date(),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 942 3/6",
            parsedData: ["puzzleNumber": "942"]
        )
    )
}
