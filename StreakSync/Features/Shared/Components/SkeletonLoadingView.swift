//
//  SkeletonLoadingView.swift
//  StreakSync
//
//  Enhanced skeleton loading with shimmer effect
//

/*
 * SKELETONLOADINGVIEW - ELEGANT LOADING STATES WITH SHIMMER ANIMATIONS
 * 
 * WHAT THIS FILE DOES:
 * This file provides beautiful skeleton loading animations that show placeholder content
 * while data is being loaded. It's like a "loading placeholder system" that displays
 * animated, shimmering shapes that mimic the final content layout. Think of it as the
 * "loading state manager" that makes waiting feel shorter and more engaging by showing
 * users what's coming instead of blank screens or spinners.
 * 
 * WHY IT EXISTS:
 * Loading states are crucial for good user experience - they help users understand that
 * content is being loaded and provide visual feedback about what to expect. Instead of
 * showing blank screens or generic spinners, this component provides animated skeleton
 * placeholders that match the final content layout, making the app feel more responsive
 * and professional.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides essential loading state feedback throughout the app
 * - Creates beautiful, animated skeleton loading states
 * - Supports different skeleton styles (card, list, grid, text) for different content types
 * - Uses shimmer animations to make loading feel more engaging
 * - Provides consistent loading experience across all features
 * - Makes the app feel more responsive and professional
 * - Reduces perceived loading time with engaging animations
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and animations
 * - SkeletonStyle: Enum defining different skeleton loading styles
 * - LinearGradient: For creating shimmer effects
 * - Animation: For smooth loading animations
 * - Color: For consistent skeleton colors and theming
 * - RoundedRectangle: For creating skeleton shapes
 * 
 * WHAT REFERENCES IT:
 * - Dashboard views: Use this while loading game data
 * - Achievement views: Use this while loading achievement data
 * - Game lists: Use this while loading game information
 * - Search results: Use this while loading search data
 * - Various feature views: Use this for consistent loading states
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. SKELETON STYLE IMPROVEMENTS:
 *    - The current styles are good but could be more sophisticated
 *    - Consider adding more skeleton variations and layouts
 *    - Add support for custom skeleton configurations
 *    - Implement smart skeleton selection based on content type
 * 
 * 2. ANIMATION IMPROVEMENTS:
 *    - The current animations are good but could be enhanced
 *    - Consider adding more sophisticated shimmer effects
 *    - Add support for custom animation configurations
 *    - Implement smart animation selection based on context
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient skeleton rendering
 *    - Add support for skeleton caching and reuse
 *    - Implement smart skeleton management
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current skeleton system could be more user-friendly
 *    - Add support for skeleton customization and preferences
 *    - Implement smart skeleton recommendations
 *    - Add support for skeleton tutorials and guidance
 * 
 * 5. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for skeleton logic
 *    - Test different skeleton styles and configurations
 *    - Add UI tests for skeleton animations
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for skeleton features
 *    - Document the different skeleton styles and usage patterns
 *    - Add examples of how to use different skeletons
 *    - Create skeleton usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new skeleton types
 *    - Add support for custom skeleton configurations
 *    - Implement skeleton plugins
 *    - Add support for third-party skeleton integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Skeleton loading: Animated placeholders that show while content is loading
 * - Shimmer effects: Animated gradients that create a shimmering appearance
 * - Loading states: UI components that show when data is being fetched
 * - User experience: Making sure the app feels responsive and engaging
 * - Animations: Visual effects that make loading feel more dynamic
 * - Placeholder content: Temporary content that shows the expected layout
 * - Performance: Making sure loading states don't slow down the app
 * - Accessibility: Making sure loading states work for all users
 * - Visual feedback: Providing users with information about app state
 * - Design systems: Standardized approaches to creating consistent experiences
 */

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
