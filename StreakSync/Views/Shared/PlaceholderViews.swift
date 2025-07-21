//
//  DetailViews.swift
//  StreakSync
//
//  Simplified detail views for game results and achievements
//

import SwiftUI

// MARK: - Game Result Detail View
struct GameResultDetailView: View {
    let result: GameResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Score display
                    VStack(spacing: Spacing.md) {
                        Text(result.scoreEmoji)
                            .font(.system(size: 72))
                        
                        Text(result.gameName.capitalized)
                            .font(.title3.weight(.medium))
                        
                        Text(result.displayScore)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Spacing.xl)
                    
                    // Details
                    VStack(spacing: 0) {
                        DetailRow(label: "Date", value: result.date.formatted(date: .abbreviated, time: .omitted))
                        Divider()
                        DetailRow(label: "Status", value: result.completed ? "Completed" : "Not Completed")
                        Divider()
                        DetailRow(label: "Attempts", value: result.displayScore)
                        
                        if let puzzleNumber = result.parsedData["puzzleNumber"] {
                            Divider()
                            DetailRow(label: "Puzzle", value: "#\(puzzleNumber)")
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
                    
                    // Share button
                    ShareLink(item: result.sharedText) {
                        Label("Share Result", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Game Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Achievement Detail View
struct AchievementDetailView: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xxl) {
                // Achievement icon
                VStack(spacing: Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(achievement.isUnlocked ? achievement.displayColor.opacity(0.2) : Color(.systemGray6))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: achievement.iconSystemName)
                            .font(.system(size: 44))
                            .foregroundStyle(achievement.isUnlocked ? achievement.displayColor : .gray)
                    }
                    
                    VStack(spacing: Spacing.xs) {
                        Text(achievement.title)
                            .font(.title3.weight(.semibold))
                        
                        Text(achievement.isUnlocked ? "Unlocked" : "Locked")
                            .font(.subheadline)
                            .foregroundStyle(achievement.isUnlocked ? .green : .secondary)
                    }
                }
                
                // Description
                Text(achievement.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                // Unlock info
                if let unlockedDate = achievement.unlockedDate {
                    VStack(spacing: Spacing.sm) {
                        Label("Unlocked on", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(unlockedDate.formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Add Custom Game View
struct AddCustomGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gameName = ""
    @State private var gameURL = ""
    @State private var selectedCategory: GameCategory = .word
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Game Information") {
                    TextField("Game Name", text: $gameName)
                    TextField("Game URL", text: $gameURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(GameCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.iconSystemName)
                                .tag(category)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Custom game support coming soon!")
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Add Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row Helper
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
        }
        .padding()
    }
}

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

#Preview("Achievement Detail") {
    AchievementDetailView(
        achievement: Achievement(
            title: "Week Warrior",
            description: "Maintain a 7-day streak",
            iconSystemName: "flame.fill",
            requirement: .streakLength(7),
            unlockedDate: Date()
        )
    )
}
