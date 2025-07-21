import SwiftUI

/// Optimized animated gradient that provides visual interest without performance cost
struct OptimizedAnimatedGradient: View {
    let colors: [Color]
    @State private var animationPhase: Double = 0
    
    var body: some View {
        // Use a simple animated gradient instead of complex mesh
        ZStack {
            // Base gradient
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated overlay gradient
            LinearGradient(
                colors: [
                    colors[0].opacity(0.5),
                    colors[1].opacity(0.3),
                    colors.count > 2 ? colors[2].opacity(0.5) : colors[0].opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .scaleEffect(1.5)
            .rotationEffect(.degrees(animationPhase))
            .blendMode(.plusLighter)
            .opacity(0.5)
            
            // Subtle moving blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            colors[0].opacity(0.4),
                            colors[0].opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 300, height: 300)
                .offset(
                    x: cos(animationPhase * .pi / 180) * 100,
                    y: sin(animationPhase * .pi / 180) * 100
                )
                .blur(radius: 40)
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 20)
                    .repeatForever(autoreverses: false)
            ) {
                animationPhase = 360
            }
        }
    }
}


/// Ambient animated background for dashboard
struct AmbientBackground: View {
    let colors: [Color]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Base color
            Color(colorScheme == .dark ? .black : Color(hex: "FAFAF9"))
            
            // Static gradient base
            LinearGradient(
                colors: colors + [colors[0]],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 0.2 : 0.1)
            
            // Animated accent blobs
            ForEach(0..<3, id: \.self) { index in
                AnimatedBlob(
                    color: colors[index % colors.count],
                    delay: Double(index) * 2,
                    scale: 1.0 - (Double(index) * 0.2)
                )
            }
        }
        .ignoresSafeArea()
    }
}

/// Individual animated blob component
private struct AnimatedBlob: View {
    let color: Color
    let delay: Double
    let scale: Double
    
    @State private var offset = CGSize.zero
    @State private var opacity: Double = 0.3
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.6),
                        color.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 150
                )
            )
            .frame(width: 300 * scale, height: 300 * scale)
            .blur(radius: 60)
            .opacity(opacity)
            .offset(offset)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 8)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    offset = CGSize(
                        width: CGFloat.random(in: -100...100),
                        height: CGFloat.random(in: -100...100)
                    )
                    opacity = Double.random(in: 0.2...0.5)
                }
            }
    }
}

// MARK: - Usage Examples

struct DashboardBackgroundView: View {
    let timeBasedGradient: [Color]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Use the ambient background for best performance
            AmbientBackground(colors: timeBasedGradient)
            
            // Or use the optimized gradient for simpler animation
            // OptimizedAnimatedGradient(colors: timeBasedGradient)
            //     .opacity(colorScheme == .dark ? 0.3 : 0.15)
            //     .blur(radius: 40)
        }
    }
}

// MARK: - Preview
#Preview("Optimized Backgrounds") {
    VStack(spacing: 0) {
        // Morning gradient
        AmbientBackground(
            colors: [Color(hex: "FF6B6B"), Color(hex: "FFE66D"), Color(hex: "FF6B6B")]
        )
        
        // Day gradient
        AmbientBackground(
            colors: [Color(hex: "4ECDC4"), Color(hex: "44A3FC"), Color(hex: "667EEA")]
        )
    }
}
