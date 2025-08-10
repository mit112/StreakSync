//
//  HideTabBarModifier.swift
//  StreakSync
//
//  Modifier to hide tab bar on detail views
//

import SwiftUI

struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .toolbar(.hidden, for: .tabBar)
            #endif
    }
}

extension View {
    func hideTabBar() -> some View {
        modifier(HideTabBarModifier())
    }
}
