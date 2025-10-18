//
//  AnimatedButton.swift
//  StreakSync
//
//  Minimalist button component following HIG guidelines
//

/*
 * ANIMATEDBUTTON - INTERACTIVE BUTTON COMPONENTS WITH ENGAGING ANIMATIONS
 * 
 * WHAT THIS FILE DOES:
 * This file provides reusable button components with smooth animations and haptic feedback.
 * It's like a "button factory" that creates consistent, engaging buttons throughout the app.
 * Think of it as the "interactive element system" that makes all buttons feel responsive
 * and satisfying to tap, with proper animations, haptic feedback, and accessibility support.
 * 
 * WHY IT EXISTS:
 * The app needs consistent, engaging buttons that provide good user feedback. Instead of
 * using basic system buttons, this component provides enhanced buttons with animations,
 * haptic feedback, and proper accessibility support. It ensures all buttons in the app
 * feel cohesive and provide satisfying interaction feedback.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides consistent button interactions throughout the app
 * - Creates engaging, animated buttons with haptic feedback
 * - Supports different button styles (primary, secondary) for different use cases
 * - Ensures proper accessibility support for all buttons
 * - Provides consistent visual design and interaction patterns
 * - Makes the app feel more polished and responsive
 * - Reduces code duplication for button creation
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For button components and animations
 * - HapticManager: For tactile feedback on button interactions
 * - SafeSFSymbol: For safe icon display with fallbacks
 * - Spacing: For consistent spacing throughout the app
 * - Layout: For consistent sizing and touch targets
 * - CornerRadius: For consistent corner radius values
 * 
 * WHAT REFERENCES IT:
 * - All feature views: Use this for consistent button interactions
 * - Settings screens: Use this for action buttons
 * - Game interfaces: Use this for game action buttons
 * - Achievement views: Use this for celebration buttons
 * - Various UI components: Use this for interactive elements
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. BUTTON STYLE IMPROVEMENTS:
 *    - The current styles are basic - could be more sophisticated
 *    - Consider adding more button styles and variations
 *    - Add support for custom button configurations
 *    - Implement smart button style selection based on context
 * 
 * 2. ANIMATION IMPROVEMENTS:
 *    - The current animations are good but could be enhanced
 *    - Consider adding more sophisticated animation effects
 *    - Add support for custom animation configurations
 *    - Implement smart animation selection based on context
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current button system could be more user-friendly
 *    - Add support for button customization and preferences
 *    - Implement smart button recommendations
 *    - Add support for button tutorials and guidance
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient button rendering
 *    - Add support for button caching and reuse
 *    - Implement smart button management
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for button logic
 *    - Test different button styles and configurations
 *    - Add UI tests for button interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for button features
 *    - Document the different button styles and usage patterns
 *    - Add examples of how to use different buttons
 *    - Create button usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new button types
 *    - Add support for custom button configurations
 *    - Implement button plugins
 *    - Add support for third-party button integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Button components: Interactive UI elements that respond to user taps
 * - Animations: Visual effects that make interactions feel smooth and engaging
 * - Haptic feedback: Tactile sensations that provide physical feedback
 * - Accessibility: Making sure buttons work for users with different needs
 * - User experience: Making sure interactions feel satisfying and responsive
 * - Component libraries: Collections of reusable UI components
 * - Consistent styling: Making sure all buttons look and behave the same way
 * - Touch targets: Making sure buttons are easy to tap accurately
 * - Visual feedback: Providing users with information about their actions
 * - Design systems: Standardized approaches to creating consistent experiences
 */

import SwiftUI

// MARK: - Button Style Enum (Simplified)
enum AnimatedButtonStyle {
    case primary      // Blue filled button for primary actions
    case secondary    // System background for secondary actions
    
    var backgroundColor: Color {
        switch self {
        case .primary: return .blue
        case .secondary: return Color(.secondarySystemBackground)
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary: return .white
        case .secondary: return .primary
        }
    }
}

// MARK: - Simplified Button Component
struct AnimatedButton: View {
    let title: String
    let icon: String?
    let style: AnimatedButtonStyle
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        style: AnimatedButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: performAction) {
            HStack(spacing: Spacing.sm) {
                if let icon = icon {
                    Image.safeSystemName(icon, fallback: "button")
                        .font(.body)
                }
                
                Text(title)
                    .font(.body.weight(.medium))
            }
            .foregroundStyle(style.foregroundColor)
            .frame(minHeight: Layout.minTouchTarget)
            .padding(.horizontal, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(style.backgroundColor)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.standard) {
                    isPressed = pressing
                }
            },
            perform: { }
        )
        .accessibilityAddTraits(.isButton)
    }
    
    private func performAction() {
        HapticManager.selection()
        action()
    }
}

// MARK: - Simple Icon Button
struct IconButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: performAction) {
            Image.safeSystemName(icon, fallback: "button")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                .background(
                    Circle()
                        .fill(Color(.tertiarySystemFill))
                        .opacity(isPressed ? 0.5 : 0)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.standard) {
                    isPressed = pressing
                }
            },
            perform: { }
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
    
    private func performAction() {
        HapticManager.selection()
        action()
    }
}

// MARK: - Text Button (iOS Native Style)
struct TextButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("Minimalist Buttons") {
    VStack(spacing: Spacing.xl) {
        // Primary actions
        AnimatedButton("Play Game", icon: "play.fill", style: .primary) {
            print("Primary action")
        }
        
        // Secondary actions
        AnimatedButton("View Details", style: .secondary) {
            print("Secondary action")
        }
        
        // Icon buttons in toolbar style
        HStack(spacing: Spacing.lg) {
            IconButton(icon: "gear", label: "Settings") {
                print("Settings")
            }
            
            IconButton(icon: "bell", label: "Notifications") {
                print("Notifications")
            }
            
            IconButton(icon: "square.and.arrow.up", label: "Share") {
                print("Share")
            }
        }
        
        // Text button
        TextButton(title: "View All") {
            print("View all")
        }
        
        Spacer()
    }
    .padding()
}
