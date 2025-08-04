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
            .onChange(of: text) { _, newText in
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

// MARK: - Animated Number Text
struct AnimatedNumberText: View {
    let value: Int
    let font: Font
    let color: Color
    let duration: Double
    
    @State private var displayValue: Int = 0
    
    init(
        value: Int,
        font: Font = .body,
        color: Color = .primary,
        duration: Double = 0.5
    ) {
        self.value = value
        self.font = font
        self.color = color
        self.duration = duration
    }
    
    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .onAppear {
                animateValue()
            }
            .onChange(of: value) { _, newValue in
                animateValue()
            }
    }
    
    private func animateValue() {
        let steps = 20
        let stepDuration = duration / Double(steps)
        let increment = value / steps
        
        displayValue = 0
        
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                withAnimation(.linear(duration: stepDuration)) {
                    if step == steps {
                        displayValue = value
                    } else {
                        displayValue = increment * step
                    }
                }
                
                // Haptic tick for each step
                if step % 5 == 0 {
                    HapticManager.shared.trigger(.buttonTap)
                }
            }
        }
    }
}
