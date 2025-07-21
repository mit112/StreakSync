//
//  GameIcon.swift
//  StreakSync
//
//  Created by MiT on 7/24/25.
//

import SwiftUI

struct GameIcon: View {
    let icon: String
    let backgroundColor: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [backgroundColor, backgroundColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: backgroundColor.opacity(0.3), radius: 8, x: 0, y: 4)

            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(.white)
        }
    }
}
