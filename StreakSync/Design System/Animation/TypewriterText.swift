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
    @State private var currentIndex = 0
    
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
            .onAppear {
                typeText()
            }
            .onChange(of: text) { _, _ in
                // Reset if text changes
                displayedText = ""
                currentIndex = 0
                typeText()
            }
    }
    
    private func typeText() {
        guard currentIndex < text.count else {
            onComplete?()
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + characterDelay) {
            // Double-check bounds in case text changed during animation
            guard currentIndex < text.count else {
                onComplete?()
                return
            }
            
            let index = text.index(text.startIndex, offsetBy: currentIndex)
            displayedText += String(text[index])
            currentIndex += 1
            
            // Trigger haptic for certain characters
            if text[index] == "!" || text[index] == "." {
                HapticManager.shared.trigger(.buttonTap)
            }
            
            typeText()
        }
    }
}
