////
////  CelebrationEnhancements.swift
////  StreakSync
////
////  Additional celebration effects and utilities
////
//
//import SwiftUI
//
//// MARK: - Particle Emitter View
//struct ParticleEmitterView: View {
//    let particleCount: Int
//    let duration: Double
//    let colors: [Color]
//    let startPoint: CGPoint
//    
//    @State private var particles: [Particle] = []
//    
//    struct Particle: Identifiable {
//        let id = UUID()
//        var position: CGPoint
//        var velocity: CGVector
//        var color: Color
//        var size: CGFloat
//        var lifetime: Double
//    }
//    
//    var body: some View {
//        TimelineView(.animation) { timeline in
//            Canvas { context, size in
//                let elapsedTime = timeline.date.timeIntervalSince1970
//                
//                for particle in particles {
//                    let progress = min(1.0, (elapsedTime - particle.lifetime) / duration)
//                    let opacity = 1.0 - progress
//                    
//                    let x = particle.position.x + particle.velocity.dx * progress * 200
//                    let y = particle.position.y + particle.velocity.dy * progress * 200 + 
//                           (progress * progress * 300) // Gravity effect
//                    
//                    context.fill(
//                        Circle().path(in: CGRect(
//                            x: x - particle.size / 2,
//                            y: y - particle.size / 2,
//                            width: particle.size,
//                            height: particle.size
//                        )),
//                        with: .color(particle.color.opacity(opacity))
//                    )
//                }
//            }
//        }
//        .onAppear {
//            createParticles()
//        }
//    }
//    
//    private func createParticles() {
//        particles = (0..<particleCount).map { _ in
//            Particle(
//                position: startPoint,
//                velocity: CGVector(
//                    dx: Double.random(in: -1...1),
//                    dy: Double.random(in: -2...-0.5)
//                ),
//                color: colors.randomElement() ?? .blue,
//                size: CGFloat.random(in: 4...12),
//                lifetime: Date().timeIntervalSince1970
//            )
//        }
//    }
//}
//
//// MARK: - Ripple Effect View
//struct RippleEffectView: View {
//    @State private var scale: CGFloat = 0.5
//    @State private var opacity: Double = 1.0
//    let color: Color
//    
//    var body: some View {
//        Circle()
//            .stroke(color, lineWidth: 3)
//            .scaleEffect(scale)
//            .opacity(opacity)
//            .onAppear {
//                withAnimation(.easeOut(duration: 1.0)) {
//                    scale = 2.0
//                    opacity = 0
//                }
//            }
//    }
//}
//
//// MARK: - Glow Effect Modifier
//struct GlowModifier: ViewModifier {
//    let color: Color
//    let radius: CGFloat
//    @State private var isGlowing = false
//    
//    func body(content: Content) -> some View {
//        content
//            .shadow(
//                color: isGlowing ? color : color.opacity(0.3),
//                radius: isGlowing ? radius : radius / 2
//            )
//            .animation(
//                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
//                value: isGlowing
//            )
//            .onAppear {
//                isGlowing = true
//            }
//    }
//}
//
//extension View {
//    func glow(color: Color = .blue, radius: CGFloat = 10) -> some View {
//        modifier(GlowModifier(color: color, radius: radius))
//    }
//}
//
//// MARK: - Bounce Effect
//struct BounceEffect: GeometryEffect {
//    var time: Double
//    let duration: Double
//    let height: CGFloat
//    
//    var animatableData: Double {
//        get { time }
//        set { time = newValue }
//    }
//    
//    func effectValue(size: CGSize) -> ProjectionTransform {
//        let relativeTime = time.truncatingRemainder(dividingBy: duration) / duration
//        let bounce = sin(relativeTime * .pi) * height
//        return ProjectionTransform(CGAffineTransform(translationX: 0, y: -bounce))
//    }
//}
//
//// MARK: - Celebration Badge
//struct CelebrationBadge: View {
//    let icon: String
//    let title: String
//    let subtitle: String
//    let color: Color
//    
//    @State private var isVisible = false
//    @State private var badgeScale: CGFloat = 0.1
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Badge icon
//            ZStack {
//                Circle()
//                    .fill(
//                        RadialGradient(
//                            colors: [color.opacity(0.3), color.opacity(0.1)],
//                            center: .center,
//                            startRadius: 0,
//                            endRadius: 60
//                        )
//                    )
//                    .frame(width: 120, height: 120)
//                
//                Circle()
//                    .fill(color)
//                    .frame(width: 80, height: 80)
//                    .glow(color: color, radius: 20)
//                
//                Image(systemName: icon)
//                    .font(.system(size: 40, weight: .bold))
//                    .foregroundColor(.white)
//            }
//            .scaleEffect(badgeScale)
//            .modifier(BounceEffect(time: isVisible ? 1 : 0, duration: 0.6, height: 20))
//            
//            // Text
//            VStack(spacing: 4) {
//                Text(title)
//                    .font(.title3.bold())
//                    .foregroundColor(.primary)
//                
//                Text(subtitle)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            .padding(.top, 16)
//            .opacity(isVisible ? 1 : 0)
//        }
//        .onAppear {
//            withAnimation(SpringPreset.bouncy) {
//                badgeScale = 1.0
//                isVisible = true
//            }
//        }
//    }
//}
//
//// MARK: - Streak Fire Animation
//struct StreakFireAnimation: View {
//    @State private var flameOffset: CGFloat = 0
//    @State private var flameScale: CGFloat = 1.0
//    let streakCount: Int
//    
//    var body: some View {
//        ZStack {
//            // Base flame
//            Image(systemName: "flame.fill")
//                .font(.system(size: 100))
//                .foregroundStyle(
//                    LinearGradient(
//                        colors: [.orange, .red],
//                        startPoint: .bottom,
//                        endPoint: .top
//                    )
//                )
//                .scaleEffect(flameScale)
//                .offset(y: flameOffset)
//            
//            // Inner flame
//            Image(systemName: "flame.fill")
//                .font(.system(size: 70))
//                .foregroundStyle(
//                    LinearGradient(
//                        colors: [.yellow, .orange],
//                        startPoint: .bottom,
//                        endPoint: .top
//                    )
//                )
//                .scaleEffect(flameScale * 0.8)
//                .offset(y: flameOffset * 0.8)
//                .opacity(0.8)
//            
//            // Streak number
//            Text("\(streakCount)")
//                .font(.system(size: 40, weight: .black, design: .rounded))
//                .foregroundColor(.white)
//                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
//        }
//        .onAppear {
//            withAnimation(
//                Animation.easeInOut(duration: 1.5)
//                    .repeatForever(autoreverses: true)
//            ) {
//                flameOffset = -10
//                flameScale = 1.1
//            }
//        }
//    }
//}
//
//// MARK: - Achievement Unlock Animation
//struct AchievementUnlockView: View {
//    let achievement: Achievement
//    @State private var isShowingDetails = false
//    @State private var lockRotation: Double = 0
//    @State private var lockScale: CGFloat = 1.0
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Lock animation
//            ZStack {
//                if !isShowingDetails {
//                    Image(systemName: "lock.fill")
//                        .font(.system(size: 60))
//                        .foregroundColor(.gray)
//                        .rotationEffect(.degrees(lockRotation))
//                        .scaleEffect(lockScale)
//                } else {
//                    Image(systemName: achievement.iconName)
//                        .font(.system(size: 60))
//                        .foregroundStyle(
//                            LinearGradient(
//                                colors: [.yellow, .orange],
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            )
//                        )
//                        .transition(.scale.combined(with: .opacity))
//                }
//            }
//            
//            if isShowingDetails {
//                VStack(spacing: 8) {
//                    Text("Achievement Unlocked!")
//                        .font(.headline)
//                        .foregroundColor(.secondary)
//                    
//                    Text(achievement.name)
//                        .font(.title2.bold())
//                    
//                    Text(achievement.description)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.center)
//                }
//                .transition(.move(edge: .bottom).combined(with: .opacity))
//            }
//        }
//        .padding(40)
//        .onAppear {
//            // Lock shake animation
//            withAnimation(
//                Animation.linear(duration: 0.1)
//                    .repeatCount(5, autoreverses: true)
//            ) {
//                lockRotation = 10
//            }
//            
//            // Lock break animation
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                withAnimation(SpringPreset.bouncy) {
//                    lockScale = 0.1
//                }
//                
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    withAnimation(SpringPreset.bouncy) {
//                        isShowingDetails = true
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - Celebration Sound Manager
//class CelebrationSoundManager {
//    static let shared = CelebrationSoundManager()
//    
//    @AppStorage("celebrationSounds") private var soundsEnabled = false
//    
//    func playSound(for type: CelebrationManager.CelebrationType) {
//        guard soundsEnabled else { return }
//        
//        // Play appropriate sound based on celebration type
//        // Implementation would use AVAudioPlayer or similar
//        // For now, this is a placeholder
//        
//        switch type.intensity {
//        case .subtle:
//            // Play subtle chime
//            break
//        case .medium:
//            // Play success sound
//            break
//        case .epic:
//            // Play fanfare
//            break
//        }
//    }
//}
//
//// MARK: - Usage Example
//struct CelebrationShowcase: View {
//    @State private var showBadge = false
//    @State private var showAchievement = false
//    @State private var showFire = false
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 40) {
//                // Celebration Badge
//                if showBadge {
//                    CelebrationBadge(
//                        icon: "star.fill",
//                        title: "Week Complete!",
//                        subtitle: "7 day streak",
//                        color: .purple
//                    )
//                }
//                
//                Button("Show Badge") {
//                    showBadge.toggle()
//                }
//                .pressable()
//                
//                // Achievement Unlock
//                if showAchievement {
//                    AchievementUnlockView(
//                        achievement: Achievement(
//                            id: UUID(),
//                            name: "First Week",
//                            description: "Complete a 7-day streak",
//                            iconName: "calendar.badge.checkmark",
//                            requirement: .streakDays(gameId: nil, days: 7),
//                            unlockedDate: Date(),
//                            category: .streak
//                        )
//                    )
//                }
//                
//                Button("Show Achievement") {
//                    showAchievement.toggle()
//                }
//                .pressable()
//                
//                // Streak Fire
//                if showFire {
//                    StreakFireAnimation(streakCount: 30)
//                        .frame(height: 150)
//                }
//                
//                Button("Show Fire") {
//                    showFire.toggle()
//                }
//                .pressable()
//            }
//            .padding()
//        }
//    }
//}
//
//// MARK: - Preview
//#Preview("Celebration Enhancements") {
//    CelebrationShowcase()
//        .celebrationContainer()
//        .environmentObject(ThemeManager.shared)
//}
