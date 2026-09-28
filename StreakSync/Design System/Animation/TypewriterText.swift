//
//  TypewriterText.swift
//  StreakSync
//
//  Animated text that types character by character
//

import SwiftUI

// MARK: - Typewriter Text View
struct TypewriterText: View {
    let text: String
    let font: Font
    let color: Color
    let characterDelay: Double
    let onComplete: (() -> Void)?
    
    @State private var displayedText = ""
    
    init(
        _ text: String,
        font: Font = .body,
        color: Color = .primary,
        characterDelay: Double = 0.03,
        onComplete: (() -> Void)? = nil
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.characterDelay = characterDelay
        self.onComplete = onComplete
    }
    
    var body: some View {
        Text(displayedText)
            .font(font)
            .foregroundStyle(color)
            // Keyed on `text`, so a new string cancels the old run instead of
            // interleaving a second typing loop with it.
            .task(id: text) {
                displayedText = ""
                for character in text {
                    do {
                        try await Task.sleep(for: .seconds(characterDelay))
                    } catch {
                        return
                    }
                    displayedText.append(character)
                    if character == "!" || character == "." {
                        HapticManager.shared.trigger(.buttonTap)
                    }
                }
                onComplete?()
            }
    }
}
