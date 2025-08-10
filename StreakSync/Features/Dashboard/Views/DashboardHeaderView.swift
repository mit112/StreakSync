//
//  DashboardHeaderView.swift
//  StreakSync
//
//  Dashboard header component with app name, progress badges, and search toggle
//

import SwiftUI

struct DashboardHeaderView: View {
    // MARK: - Properties
    let activeStreakCount: Int
    let todayCompletedCount: Int
    let greetingText: String
    
    @Binding var isSearching: Bool
    @Binding var searchText: String
    @FocusState.Binding var isSearchFieldFocused: Bool
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 8) {
            // App name and progress indicators
            HStack {
                Text("StreakSync")
                    .font(.largeTitle.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                // Compact progress indicators
                HStack(spacing: 8) {
                    CompactProgressBadge(
                        icon: "flame.fill",
                        value: activeStreakCount,
                        color: .orange
                    )
                    
                    CompactProgressBadge(
                        icon: "checkmark.circle.fill",
                        value: todayCompletedCount,
                        color: .green
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Dynamic greeting with search toggle
            HStack {
                Text(greetingText)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: greetingText)
                
                Spacer()
                
                // Search toggle button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isSearching.toggle()
                        if isSearching {
                            isSearchFieldFocused = true
                        } else {
                            searchText = ""
                            isSearchFieldFocused = false
                        }
                    }
                } label: {
                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .pressable(hapticType: .buttonTap, scaleAmount: 0.9)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    DashboardHeaderPreviewWrapper()
}

private struct DashboardHeaderPreviewWrapper: View {
    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        DashboardHeaderView(
            activeStreakCount: 5,
            todayCompletedCount: 3,
            greetingText: "Good morning, Sarah! ☀️",
            isSearching: $isSearching,
            searchText: $searchText,
            isSearchFieldFocused: $isSearchFieldFocused
        )
        .padding()
    }
}
