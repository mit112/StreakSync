//
//  GameDetailPrimaryActions.swift
//  StreakSync
//
//  Primary action buttons for game detail view
//

import SwiftUI

struct GameDetailPrimaryActions: View {
    let game: Game
    @Binding var showingManualEntry: Bool
    @Binding var isLoadingGame: Bool
    let onPlayGame: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Play Game Button
            PlayGameButton(
                game: game,
                isLoading: isLoadingGame,
                action: onPlayGame
            )
            
            // Manual Entry Button
            ManualEntryButton(
                showingManualEntry: $showingManualEntry
            )
        }
    }
}

// MARK: - Play Game Button
private struct PlayGameButton: View {
    let game: Game
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        // One prominent accent-blue action (DESIGN_AUDIT §5.2, decision A): white
        // text on the game's own color failed WCAG contrast (~1.5–2.1:1 for the
        // light games). Per-game identity stays on the hero icon/title.
        Button(action: action) {
            Label("Play \(game.displayName)", systemImage: "play.fill")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .pressable(hapticType: .buttonTap)
        .hoverable()
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
}

// MARK: - Manual Entry Button
private struct ManualEntryButton: View {
    @Binding var showingManualEntry: Bool

    var body: some View {
        Button {
            showingManualEntry = true
        } label: {
            Label("Add Result", systemImage: "keyboard")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
        }
        .modifier(AdaptiveGlassButtonStyle())
        .pressable(hapticType: .buttonTap)
        .hoverable()
    }
}

private struct AdaptiveGlassButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *) {
                content.buttonStyle(.glass)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GameDetailPrimaryActions(
        game: Game.wordle,
        showingManualEntry: .constant(false),
        isLoadingGame: .constant(false),
        onPlayGame: {}
    )
    .padding()
}
