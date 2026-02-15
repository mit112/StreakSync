//
//  CelebrationEffects.swift
//  StreakSync
//
//  Particle system, confetti explosion, and supporting shapes for achievement celebrations
//

import SwiftUI

// MARK: - Enhanced Particle System
struct EnhancedParticleSystem: View {
    let tier: AchievementTier
    @Binding var isActive: Bool
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var scale: CGFloat
        var opacity: Double
        var rotation: Double
        let shape: ParticleShape
        
        enum ParticleShape: CaseIterable {
            case circle, star, plus, diamond
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                ParticleView(particle: particle, color: tier.color)
                    .position(particle.position)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .rotationEffect(Angle(degrees: particle.rotation))
            }
            .onAppear {
                createParticles(geometry: geometry)
                animateParticles()
            }
        }
        .accessibilityHidden(true)
    }
    
    private func createParticles(geometry: GeometryProxy) {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        let particleCount = ProcessInfo.processInfo.processorCount > 4 ? 30 : 15
        
        for _ in 0..<particleCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 100...300)
            
            particles.append(Particle(
                position: CGPoint(x: centerX, y: centerY),
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0,
                rotation: Double.random(in: 0...360),
                shape: Particle.ParticleShape.allCases.randomElement()!
            ))
        }
    }
    
    private func animateParticles() {
        withAnimation(.easeOut(duration: 2.0)) {
            for index in particles.indices {
                particles[index].position.x += particles[index].velocity.dx
                particles[index].position.y += particles[index].velocity.dy
                particles[index].opacity = 0
                particles[index].scale *= 0.3
                particles[index].rotation += Double.random(in: -180...180)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isActive = false
        }
    }
}

// MARK: - Particle View
private struct ParticleView: View {
    let particle: EnhancedParticleSystem.Particle
    let color: Color
    
    var body: some View {
        Group {
            switch particle.shape {
            case .circle:
                Circle().fill(color).frame(width: 12, height: 12)
            case .star:
                Image(systemName: "star.fill").font(.caption).foregroundStyle(color)
            case .plus:
                Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(color)
            case .diamond:
                Image.compatibleSystemName("diamond.fill").font(.caption2).foregroundStyle(color)
            }
        }
    }
}

// MARK: - Confetti Explosion
struct ConfettiExplosion: View {
    @Binding var counter: Int
    let tier: AchievementTier
    @State private var confettiPieces: [ConfettiPiece] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    struct ConfettiPiece: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var rotation: Double
        var scale: CGFloat
        var opacity: Double
        let color: Color
        let shape: ShapeType
        
        enum ShapeType: CaseIterable {
            case rectangle, circle, triangle
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(confettiPieces) { piece in
                ConfettiShapeView(shape: piece.shape, color: piece.color)
                    .frame(width: 10, height: 10)
                    .scaleEffect(piece.scale)
                    .rotationEffect(Angle(degrees: piece.rotation))
                    .position(piece.position)
                    .opacity(piece.opacity)
            }
            .onChange(of: counter) { _, _ in
                if !reduceMotion {
                    createConfetti(geometry: geometry)
                    animateConfetti(geometry: geometry)
                }
            }
        }
        .accessibilityHidden(true)
    }
    
    private func createConfetti(geometry: GeometryProxy) {
        confettiPieces.removeAll()
        let confettiCount = ProcessInfo.processInfo.processorCount > 4 ? 100 : 50
        let colors: [Color] = [tier.color, tier.color.opacity(0.8), .white, .yellow, .orange]
        let centerX = geometry.size.width / 2
        let topY = geometry.size.height * 0.3
        
        for _ in 0..<confettiCount {
            let angle = Double.random(in: -(.pi/3)...(.pi/3)) - .pi/2
            let speed = Double.random(in: 200...500)
            
            confettiPieces.append(ConfettiPiece(
                position: CGPoint(x: centerX, y: topY),
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.8...1.2),
                opacity: 1.0,
                color: colors.randomElement()!,
                shape: ConfettiPiece.ShapeType.allCases.randomElement()!
            ))
        }
    }
    
    private func animateConfetti(geometry: GeometryProxy) {
        withAnimation(.easeOut(duration: 0.5)) {
            for index in confettiPieces.indices {
                confettiPieces[index].position.x += confettiPieces[index].velocity.dx * 0.3
                confettiPieces[index].position.y += confettiPieces[index].velocity.dy * 0.3
            }
        }
        withAnimation(.easeIn(duration: 2.5).delay(0.5)) {
            for index in confettiPieces.indices {
                confettiPieces[index].position.y = geometry.size.height + 50
                confettiPieces[index].rotation += Double.random(in: -720...720)
                confettiPieces[index].opacity = 0.8
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            confettiPieces.removeAll()
        }
    }
}

// MARK: - Confetti Shape View
private struct ConfettiShapeView: View {
    let shape: ConfettiExplosion.ConfettiPiece.ShapeType
    let color: Color
    
    var body: some View {
        switch shape {
        case .rectangle: Rectangle().fill(color)
        case .circle: Circle().fill(color)
        case .triangle: Triangle().fill(color)
        }
    }
}

// MARK: - Triangle Shape
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Tier Miniature Badge
struct TierMiniatureBadge: View {
    let tier: AchievementTier
    
    var body: some View {
        ZStack {
            Circle()
                .fill(tier.color)
                .frame(width: 32, height: 32)
            
            Image.safeSystemName(tier.iconSystemName, fallback: "trophy.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: tier.color.opacity(0.5), radius: 4, x: 0, y: 2)
        .accessibilityHidden(true)
    }
}
