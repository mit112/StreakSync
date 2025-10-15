//
//  GameDetailComponents.swift
//  StreakSync
//
//  Supporting components for game detail views
//

import SwiftUI

// MARK: - Animated Stat Pill
struct AnimatedStatPill: View {
    let value: String
    let label: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(
                    isActive ?
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                    .default,
                    value: isActive
                )
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .glassCard(depth: .subtle)
        .pressable(hapticType: .buttonTap, scaleAmount: 0.95)
    }
}

// MARK: - Game Result Row
struct GameResultRow: View {
    let result: GameResult
    var onDelete: (() -> Void)? = nil
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            HapticManager.shared.trigger(.toggleSwitch)
            showingDetail = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.displayScore)
                        .font(.headline)
                        .foregroundStyle(result.completed ? .green : .orange)
                    
                    Text(result.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .glassCard()
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            GameResultDetailView(result: result, onDelete: onDelete)
        }
    }
}

// MARK: - Empty Results Card
struct EmptyResultsCard: View {
    let gameName: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No results yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Play \(gameName) to see results here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }
}

