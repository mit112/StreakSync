//
//  AnimatedButton.swift
//  StreakSync
//
//  Minimalist button component following HIG guidelines
//

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
