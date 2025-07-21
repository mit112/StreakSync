//
//  LoadingStates.swift
//  StreakSync
//
//  Native iOS loading patterns without custom animations
//

import SwiftUI

// MARK: - Loading State View
struct LoadingStateView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                AnimatedButton(actionTitle, action: action)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View
struct ErrorStateView: View {
    let error: Error
    let retry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            VStack(spacing: Spacing.sm) {
                Text("Something went wrong")
                    .font(.headline)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let retry = retry {
                AnimatedButton("Try Again", icon: "arrow.clockwise", action: retry)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pull to Refresh
struct PullToRefresh: ViewModifier {
    @Binding var isRefreshing: Bool
    let action: () async -> Void
    
    func body(content: Content) -> some View {
        content
            .refreshable {
                await action()
            }
    }
}

extension View {
    func pullToRefresh(isRefreshing: Binding<Bool>, action: @escaping () async -> Void) -> some View {
        modifier(PullToRefresh(isRefreshing: isRefreshing, action: action))
    }
}

// MARK: - Skeleton View (Simple)
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
    }
}

// MARK: - Preview
#Preview("Loading States") {
    NavigationStack {
        TabView {
            LoadingStateView("Loading your streaks...")
                .tabItem { Label("Loading", systemImage: "hourglass") }
            
            EmptyStateView(
                icon: "gamecontroller",
                title: "No Games Yet",
                message: "Start playing your favorite puzzle games and share your results to track streaks.",
                actionTitle: "Add Game",
                action: { print("Add game") }
            )
            .tabItem { Label("Empty", systemImage: "tray") }
            
            ErrorStateView(
                error: NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to load data. Please check your internet connection."]),
                retry: { print("Retry") }
            )
            .tabItem { Label("Error", systemImage: "exclamationmark.triangle") }
        }
        .navigationTitle("Loading States")
    }
}
