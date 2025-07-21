//
//  GameResultRow.swift
//  StreakSync
//
//  Individual game result row component
//

import SwiftUI

struct GameResultRow: View {
    let result: GameResult
    
    var body: some View {
        HStack {
            // Score emoji
            Text(result.scoreEmoji)
                .font(.title2)
                .frame(width: 40)
            
            // Date and score info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                
                HStack {
                    Text(result.displayScore)
                        .font(.caption)
                        .foregroundStyle(result.completed ? .green : .red)
                    
                    if let puzzleNumber = result.parsedData["puzzleNumber"] {
                        Text("• Puzzle #\(puzzleNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Completion indicator
            Image(systemName: result.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.completed ? .green : .red)
                .font(.caption)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}
