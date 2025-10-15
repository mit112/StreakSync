//
//  SkeletonLoadingView.swift
//  StreakSync
//
//  Enhanced skeleton loading with shimmer effect
//

import SwiftUI

// MARK: - Skeleton Loading View
struct SkeletonLoadingView: View {
    let style: SkeletonStyle
    @State private var isAnimating = false
    
    init(style: SkeletonStyle = .card) {
        self.style = style
    }
    
    var body: some View {
        Group {
            switch style {
            case .card:
                cardSkeleton
            case .list:
                listSkeleton
            case .grid:
                gridSkeleton
            case .text:
                textSkeleton
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Card Skeleton
    private var cardSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon skeleton
                Circle()
                    .fill(shimmerGradient)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 120, height: 16)
                    
                    // Subtitle skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 80, height: 12)
                }
                
                Spacer()
            }
            
            // Progress bar skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(shimmerGradient)
                .frame(height: 8)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
    
    // MARK: - List Skeleton
    private var listSkeleton: some View {
        HStack(spacing: 16) {
            // Icon skeleton
            Circle()
                .fill(shimmerGradient)
                .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 8) {
                // Title skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 140, height: 18)
                
                // Stats skeleton
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 60, height: 14)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 80, height: 14)
                }
            }
            
            Spacer()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        }
    }
    
    // MARK: - Grid Skeleton
    private var gridSkeleton: some View {
        VStack(spacing: 12) {
            // Icon skeleton
            Circle()
                .fill(shimmerGradient)
                .frame(width: 40, height: 40)
            
            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 60, height: 14)
            
            // Stats skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 40, height: 12)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        }
    }
    
    // MARK: - Text Skeleton
    private var textSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 200, height: 16)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 150, height: 14)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(shimmerGradient)
                .frame(width: 180, height: 14)
        }
    }
    
    // MARK: - Shimmer Effect
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemGray5),
                Color(.systemGray4),
                Color(.systemGray5)
            ],
            startPoint: isAnimating ? .leading : .trailing,
            endPoint: isAnimating ? .trailing : .leading
        )
    }
}

// MARK: - Skeleton Style
enum SkeletonStyle {
    case card
    case list
    case grid
    case text
}

// MARK: - Skeleton Loading Modifier
struct SkeletonLoadingModifier: ViewModifier {
    let isLoading: Bool
    let style: SkeletonStyle
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(isLoading ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isLoading)
            
            if isLoading {
                // Overlay skeleton to avoid full view replacement flicker
                SkeletonLoadingView(style: style)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

// MARK: - View Extension
extension View {
    func skeletonLoading(isLoading: Bool, style: SkeletonStyle = .card) -> some View {
        modifier(SkeletonLoadingModifier(isLoading: isLoading, style: style))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        SkeletonLoadingView(style: .card)
        SkeletonLoadingView(style: .list)
        SkeletonLoadingView(style: .grid)
        SkeletonLoadingView(style: .text)
    }
    .padding()
}
