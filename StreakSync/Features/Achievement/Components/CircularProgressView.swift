//
//  CircularProgressView.swift
//  StreakSync
//
//  Circular progress indicator with center text
//

import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let centerText: String?
    @ScaledMetric(relativeTo: .caption2) private var strokeWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: strokeWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            
            Text(centerText ?? "\(Int(progress * 100))%")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
