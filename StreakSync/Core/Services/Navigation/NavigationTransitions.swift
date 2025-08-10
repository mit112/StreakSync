//
//  NavigationTransitions.swift
//  StreakSync
//
//  Smooth transitions for navigation
//

import SwiftUI

// MARK: - Navigation Transition Modifier
struct NavigationTransition: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .scaleEffect(isActive ? 1 : 0.95)
            .blur(radius: isActive ? 0 : 2)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isActive)
    }
}

// MARK: - Hero Animation for Game Cards
struct HeroAnimationModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        content
//            .matchedGeometryEffect(id: id, in: namespace)
    }
}

// MARK: - Tab Bar Transition
struct TabBarTransition: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : 100)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
    }
}

// MARK: - View Extensions
extension View {
    func navigationTransition(isActive: Bool = true) -> some View {
        modifier(NavigationTransition(isActive: isActive))
    }
    
    func heroAnimation(id: String, in namespace: Namespace.ID) -> some View {
        modifier(HeroAnimationModifier(id: id, namespace: namespace))
    }
    
    func tabBarTransition(isVisible: Bool) -> some View {
        modifier(TabBarTransition(isVisible: isVisible))
    }
}
