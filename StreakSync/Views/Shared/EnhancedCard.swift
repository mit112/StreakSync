//
//  EnhancedCard.swift
//  StreakSync
//
//  Minimalist card component following HIG principles
//

import SwiftUI

// MARK: - Simplified Card Component
struct EnhancedCard<Content: View>: View {
    let content: Content
    var onTap: (() -> Void)?
    
    init(
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onTap = onTap
        self.content = content()
    }
    
    var body: some View {
        content
            .if(onTap != nil) { view in
                view
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.selection()
                        onTap?()
                    }
            }
    }
}

// MARK: - Helper Extension
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

