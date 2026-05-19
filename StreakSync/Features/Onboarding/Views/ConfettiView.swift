//
//  ConfettiView.swift
//  StreakSync
//
//  Native SwiftUI confetti — Canvas + TimelineView particle system, no dependencies.
//  Respects Reduce Motion: renders nothing when accessibility setting is enabled.
//

import SwiftUI

struct ConfettiView: View {
    /// When set to true, particles begin animating from `Date.now` for `duration` seconds.
    let isActive: Bool

    /// How long particles animate (seconds). Default 3.0.
    let duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate: Date = .distantPast

    private let particleCount = 40
    private let colors: [Color] = [.red, .yellow, .green, .blue, .purple, .pink, .orange]

    var body: some View {
        Group {
            if isActive && !reduceMotion {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(startDate)
                        guard elapsed >= 0, elapsed <= duration else { return }

                        for i in 0..<particleCount {
                            let seed = Double(i)
                            let xFrac = (seed * 0.137).truncatingRemainder(dividingBy: 1.0)
                            let xBase = size.width * xFrac
                            let xDrift = sin(elapsed * 1.5 + seed) * 30
                            let y = size.height * (elapsed / duration) + seed * 7 - 60
                            let rotation = elapsed * (1.0 + seed * 0.3) * .pi
                            let opacity = max(0, 1 - elapsed / duration)

                            var ctx = context
                            ctx.translateBy(x: xBase + xDrift, y: y)
                            ctx.rotate(by: .radians(rotation))
                            let rect = CGRect(x: -4, y: -6, width: 8, height: 12)
                            ctx.fill(
                                Path(roundedRect: rect, cornerRadius: 1),
                                with: .color(colors[i % colors.count].opacity(opacity))
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startDate = .now
            }
        }
    }
}
