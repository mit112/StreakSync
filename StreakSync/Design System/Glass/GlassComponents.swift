//
//  GlassComponents.swift
//  StreakSync
//
//  Created by MiT on 7/23/25.
//

// DesignSystem/Glass/GlassComponents.swift
import SwiftUI

// MARK: - Glass Card
struct GlassCard<Content: View>: View {
    let type: GlassConstants.GlassType
    let cornerRadius: CGFloat
    let content: () -> Content
    
    init(
        type: GlassConstants.GlassType = .medium,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.type = type
        self.cornerRadius = cornerRadius
        self.content = content
    }
    
    var body: some View {
        content()
            .glassEffect(type: type)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Button
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.trigger(.buttonTap)
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
            }
            .foregroundColor(colorScheme == .dark ? .white : .primary)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .glassEffect(type: .light)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: { }
        )
    }
}

