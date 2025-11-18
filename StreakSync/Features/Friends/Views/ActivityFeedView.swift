//
//  ActivityFeedView.swift
//  StreakSync
//

import SwiftUI

struct ActivityFeedView: View {
    let reactions: [Reaction]
    @EnvironmentObject private var betaFlags: BetaFeatureFlags
    
    var body: some View {
        Group {
            if betaFlags.activityFeed {
                List {
                    if reactions.isEmpty {
                        Text("No activity yet. Send a reaction from the leaderboard to get started!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(reactions) { reaction in
                            reactionRow(reaction)
                        }
                    }
                }
                .navigationTitle("Activity Feed")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Activity feed is unavailable in this beta build.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }
    
    private func reactionRow(_ reaction: Reaction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(reaction.senderName) \(reaction.type.description) \(reaction.type.emoji)")
                .font(.headline)
            Text(relativeDateString(for: reaction.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

