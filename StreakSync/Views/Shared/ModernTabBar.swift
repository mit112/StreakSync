////
////  ModernTabBar.swift
////  StreakSync
////
////  Created by MiT on 7/29/25.
////
//
////
////  ModernTabBar.swift
////  StreakSync
////
////  Glassmorphic tab bar component
////
//
//import SwiftUI
//
//// MARK: - Modern Tab Bar
//struct ModernTabBar: View {
//    @Binding var selectedTab: Int
//    let onNavigate: (TabBarItem) -> Void
//    
//    @Environment(\.colorScheme) private var colorScheme
//    @EnvironmentObject private var container: AppContainer
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            Rectangle()
//                .fill(Color.primary.opacity(0.05))
//                .frame(height: 0.5)
//            
//            HStack(spacing: 0) {
//                ForEach(TabBarItem.allCases, id: \.self) { item in
//                    TabBarButton(
//                        item: item,
//                        isSelected: selectedTab == item.rawValue,
//                        action: {
//                            handleTabSelection(item)
//                        }
//                    )
//                }
//            }
//            .padding(.top, 8)
//            .padding(.bottom, 34) // Account for home indicator
//            .background(tabBarBackground)
//        }
//    }
//    
//    // MARK: - Tab Bar Background
//    private var tabBarBackground: some View {
//        ZStack {
//            // Glass effect
//            Rectangle()
//                .fill(.ultraThinMaterial)
//                .background(
//                    Color(colorScheme == .dark ?
//                        UIColor.systemBackground :
//                        UIColor.secondarySystemBackground).opacity(0.85)
//                )
//            
//            // Subtle gradient overlay
//            LinearGradient(
//                colors: [
//                    Color.primary.opacity(0.02),
//                    Color.clear
//                ],
//                startPoint: .top,
//                endPoint: .bottom
//            )
//        }
//        .ignoresSafeArea()
//    }
//    
//    // MARK: - Tab Selection Handler
//    private func handleTabSelection(_ item: TabBarItem) {
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//            selectedTab = item.rawValue
//        }
//        
//        HapticManager.shared.trigger(.buttonTap)
//        onNavigate(item)
//        
//        // Reset to home after navigation (except for home itself)
//        if item != .home {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                    selectedTab = TabBarItem.home.rawValue
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Tab Bar Item
//enum TabBarItem: Int, CaseIterable {
//    case home = 0
//    case stats = 1
//    case achievements = 2
//    case settings = 3
//    
//    var icon: String {
//        switch self {
//        case .home: return "house.fill"
//        case .stats: return "chart.line.uptrend.xyaxis"
//        case .achievements: return "trophy.fill"
//        case .settings: return "gearshape.fill"
//        }
//    }
//    
//    var title: String {
//        switch self {
//        case .home: return "Home"
//        case .stats: return "Stats"
//        case .achievements: return "Awards"
//        case .settings: return "Settings"
//        }
//    }
//}
//
//// MARK: - Tab Bar Button
////private struct TabBarButton: View {
////    let item: TabBarItem
////    let isSelected: Bool
////    let action: () -> Void
////    
////    @State private var isPressed = false
////    @Environment(\.colorScheme) private var colorScheme
////    
////    var body: some View {
////        Button(action: action) {
////            VStack(spacing: 6) {
////                Image(systemName: item.icon)
////                    .font(.system(size: 22, weight: .medium))
////                    .symbolEffect(.bounce.down, options: .speed(1.5), value: isSelected)
////                
////                Text(item.title)
////                    .font(.system(size: 11, weight: .medium, design: .rounded))
////            }
////            .foregroundStyle(foregroundStyle)
////            .frame(maxWidth: .infinity)
////            .contentShape(Rectangle())
////            .scaleEffect(isPressed ? 0.92 : 1.0)
////            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
////        }
////        .buttonStyle(PlainButtonStyle())
////        .simultaneousGesture(
////            DragGesture(minimumDistance: 0)
////                .onChanged { _ in isPressed = true }
////                .onEnded { _ in isPressed = false }
////        )
////    }
////    
////    private var foregroundStyle: AnyShapeStyle {
////        if isSelected {
////            return AnyShapeStyle(
////                LinearGradient(
////                    colors: colorScheme == .dark ?
////                        [Color.blue.opacity(0.8), Color.purple.opacity(0.8)] :
////                        [Color.blue, Color.purple],
////                    startPoint: .top,
////                    endPoint: .bottom
////                )
////            )
////        } else {
////            return AnyShapeStyle(Color.secondary.opacity(0.7))
////        }
////    }
//
////}
