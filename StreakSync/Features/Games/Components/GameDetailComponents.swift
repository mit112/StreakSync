//
//  GameDetailComponents.swift
//  StreakSync
//
//  Supporting components for game detail views
//

import SwiftUI

// MARK: - Animated Stat Pill
struct AnimatedStatPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: String
    let label: String
    let isActive: Bool

    private var pulsing: Bool { isActive && !reduceMotion }

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                // Numbers stay neutral — hue is reserved for state/identity, not decoration
                // (DESIGN_AUDIT §3-C). Also removes the orange→green cross-fade smear (§4.2).
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                // Perpetual pulse is disabled under Reduce Motion (§4.10).
                .scaleEffect(pulsing ? 1.1 : 1.0)
                .animation(
                    pulsing ?
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                    .default,
                    value: pulsing
                )
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .cardStyle()
        .pressable(hapticType: .buttonTap, scaleAmount: 0.95)
    }
}

// MARK: - Game Result Row
struct GameResultRow: View {
    let result: GameResult
    var onDelete: (() -> Void)?
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
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
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
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}
