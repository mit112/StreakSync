//
//  GameLeaderboardPage.swift
//  StreakSync
//

import SwiftUI

struct GameLeaderboardPage: View {
    let game: Game
    let rows: [(row: LeaderboardRow, points: Int)]
    let isLoading: Bool
    let dateLabel: String
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            contentView
        }
        .scrollBounceBehavior(.basedOnSize)
    }
    
    private var contentView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 56)
                        .redacted(reason: .placeholder)
                        .padding(.vertical, 6)
                }
            } else if rows.isEmpty {
                VStack(spacing: 12) {
                    Text("No scores for \(game.displayName)")
                        .font(.headline)
                    Text("Pick a different date or invite friends to compare.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .padding(.vertical, 8)
            } else {
                ForEach(rows.indices, id: \.self) { index in
                    let entry = rows[index]
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .frame(width: 28, alignment: .trailing)
                        GradientAvatar(initials: String(entry.row.displayName.prefix(1)))
                        Text(entry.row.displayName)
                            .font(.body)
                            .lineLimit(1)
                        Spacer()
                        Text(guessText(for: entry.points))
                            .font(.headline)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    if index != rows.indices.last {
                        Divider()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                Text("Manage friends")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    
    private func guessText(for points: Int) -> String {
        let attempts = max(1, 7 - max(0, points))
        return "\(attempts) guesses"
    }
}


