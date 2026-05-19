//
//  ShareSheetMockup.swift
//  StreakSync
//
//  Illustrative iPhone share-sheet mockup with a highlighted StreakSync icon
//

import SwiftUI

struct ShareSheetMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 12) {
            wordleResultPreview
            shareSheetRow
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var wordleResultPreview: some View {
        VStack(spacing: 6) {
            Text("Wordle 1,234  3/6")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                tileRow(colors: [.gray, .gray, .yellow, .gray, .gray])
                tileRow(colors: [.yellow, .green, .gray, .gray, .gray])
                tileRow(colors: [.green, .green, .green, .green, .green])
            }
        }
    }

    private func tileRow(colors: [Color]) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<colors.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tileColor(colors[index]))
                    .frame(width: 22, height: 22)
            }
        }
    }

    private func tileColor(_ color: Color) -> Color {
        switch color {
        case .green: return Color(red: 0.42, green: 0.67, blue: 0.39)
        case .yellow: return Color(red: 0.79, green: 0.71, blue: 0.34)
        default: return Color(red: 0.47, green: 0.49, blue: 0.49)
        }
    }

    private var shareSheetRow: some View {
        HStack(spacing: 10) {
            shareIcon(systemImage: "message.fill", tint: .green, label: "Messages")
            shareIcon(systemImage: "envelope.fill", tint: .blue, label: "Mail")
            streakSyncIcon
            shareIcon(systemImage: "ellipsis", tint: .gray, label: "More")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func shareIcon(systemImage: String, tint: Color, label: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.gradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                )
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var streakSyncIcon: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.39, green: 0.4, blue: 0.95), Color(red: 0.55, green: 0.36, blue: 0.96)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Color.purple.opacity(pulse ? 0.6 : 0.2),
                            radius: pulse ? 14 : 4, x: 0, y: 0)
                    .scaleEffect(pulse ? 1.08 : 1.0)
            }
            Text("StreakSync")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("StreakSync share-sheet icon, highlighted")
    }
}

#Preview {
    ShareSheetMockup()
        .padding()
        .background(Color(.systemGroupedBackground))
}
