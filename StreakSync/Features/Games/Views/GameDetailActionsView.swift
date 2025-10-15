//
//  GameDetailActionsView.swift
//  StreakSync
//
//  Quick actions component extracted from GameDetailView
//

import SwiftUI

// MARK: - Game Detail Actions View
struct GameDetailActionsView: View {
    let game: Game
    @StateObject private var browserLauncher = BrowserLauncher.shared
    @State private var showingManualEntry = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Quick Actions", icon: "bolt.fill")
            
            HStack(spacing: 12) {
                GameButton(game: game, browserLauncher: browserLauncher)
                AddResultButton(showingManualEntry: $showingManualEntry)
            }
            
            // LinkedIn Games Instructions
            if isLinkedInGame(game) {
                LinkedInGameInstructions()
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView(preSelectedGame: game)
        }
    }
    
    private func isLinkedInGame(_ game: Game) -> Bool {
        return game.name.lowercased().hasPrefix("linkedin")
    }
}

// MARK: - Play Game Button
private struct GameButton: View {
    let game: Game
    let browserLauncher: BrowserLauncher
    
    var body: some View {
        Button(action: playGame) {
            HStack {
                Image(systemName: "play.fill")
                Text("Play \(game.displayName)")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(game.backgroundColor.color, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    
    private func playGame() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        browserLauncher.launchGame(game)
    }
}

// MARK: - Add Result Button
private struct AddResultButton: View {
    @Binding var showingManualEntry: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: { showingManualEntry = true }) {
            HStack {
                Image(systemName: "keyboard")
                Text("Add Result")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(colorScheme == .dark ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LinkedIn Game Instructions
private struct LinkedInGameInstructions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("How to Play This Game")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Tap 'Play' to open this game directly")
                Text("2. If LinkedIn app is installed, the game opens automatically")
                Text("3. If not, you'll be taken to LinkedIn website")
                Text("4. Start playing immediately!")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading, 20)
        }
        .padding(12)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview
#Preview {
    GameDetailActionsView(game: Game.wordle)
        .padding()
}
