//
//  EmptyResultsCard.swift
//  StreakSync
//
//  Empty state for game results
//

import SwiftUI

struct EmptyResultsCard: View {
    let gameName: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.tertiary)
            
            Text("No results yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Text("Play \(gameName) and share your results to see them here!")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
