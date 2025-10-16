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
    let rankDelta: [String: Int]?
    let onManageFriends: () -> Void
    let metricText: (Int) -> String
    let myUserId: String?
    @State private var pressedIndex: Int? = nil
    
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
                    Button {
                        onManageFriends()
                    } label: {
                        Label("Invite friends", systemImage: "person.badge.plus")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.2), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
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
                            .font(.body.weight(entry.row.userId == myUserId ? .semibold : .regular))
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 8) {
                            if let delta = rankDelta?[entry.row.userId], delta != 0 {
                                Text(delta > 0 ? "↑\(delta)" : "↓\(-delta)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(delta > 0 ? .green : .red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((delta > 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12)), in: Capsule())
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Text(metricText(entry.points))
                        }
                            .font(.headline)
                    }
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(pressedIndex == index ? 0.12 : (index % 2 == 0 ? 0.04 : 0.0)))
                    )
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 50, pressing: { pressing in
                        pressedIndex = pressing ? index : nil
                    }, perform: {})
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(accessibilityLabelForRow(index: index, entry: entry)))
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
            .contentShape(Rectangle())
            .onTapGesture { onManageFriends() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension GameLeaderboardPage {
    func accessibilityLabelForRow(index: Int, entry: (row: LeaderboardRow, points: Int)) -> String {
        let rankPart = "Rank \(index + 1)"
        let namePart = entry.row.displayName
        let metricPart = metricText(entry.points)
        var deltaPart = ""
        if let delta = rankDelta?[entry.row.userId], delta != 0 {
            deltaPart = delta > 0 ? ", up \(delta) today" : ", down \(-delta) today"
        }
        return "\(rankPart), \(namePart), \(metricPart)\(deltaPart)"
    }
}
