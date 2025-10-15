//
//  NativeLargeTitleHeader.swift
//  StreakSync
//
//  Native iOS Large Title navigation with collapsing behavior
//

import SwiftUI

struct NativeLargeTitleHeader: View {
    let longestCurrentStreak: Int
    let activeStreakCount: Int
    let onStatsTap: () -> Void
    
    @Binding var searchText: String
    @FocusState.Binding var isSearchFieldFocused: Bool
    
    var body: some View {
        EmptyView() // This will be configured via navigation modifiers
    }
}

// MARK: - Toolbar Stats Chip
struct ToolbarStatChip: View {
    let icon: String
    let value: Int
    let color: Color
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image.safeSystemName(icon, fallback: "number")
                .font(.system(size: 14, weight: .semibold))
            Text("\(value)")
                .font(.system(size: 14, weight: .bold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(color.opacity(0.15))
                .overlay {
                    Capsule()
                        .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
                }
        }
        .scaleEffect(isPressed ? 0.92 : 1)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Navigation Title View Modifier
struct NativeLargeTitleModifier: ViewModifier {
    let longestCurrentStreak: Int
    let activeStreakCount: Int
    let onStatsTap: () -> Void
    @Binding var searchText: String
    
    func body(content: Content) -> some View {
        content
            .navigationTitle("StreakSync")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Stats chips in trailing position
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        onStatsTap()
                    } label: {
                        HStack(spacing: 8) {
                            ToolbarStatChip(
                                icon: "flame.fill",
                                value: longestCurrentStreak,
                                color: .orange
                            )
                            .allowsHitTesting(false)
                            
                            ToolbarStatChip(
                                icon: "bolt.fill",
                                value: activeStreakCount,
                                color: .green
                            )
                            .allowsHitTesting(false)
                            
                            // Analytics icon
                            Image.compatibleSystemName("chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View All Streaks")
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search games..."
            )
            // Add greeting as toolbar subtitle
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)
    }
}
