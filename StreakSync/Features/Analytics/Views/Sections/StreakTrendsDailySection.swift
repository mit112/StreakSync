//
//  StreakTrendsDailySection.swift
//  StreakSync
//
//  Daily activity breakdown feed for streak trends.
//

import SwiftUI

struct StreakTrendsDailySection: View {
    let trends: [StreakTrendPoint]
    @Binding var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Breakdown")
                .font(.headline)
                .fontWeight(.semibold)

            if trends.isEmpty {
                emptyActivityView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(trends.reversed(), id: \.date) { point in
                        dailyActivityRow(point)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }

    private func dailyActivityRow(_ point: StreakTrendPoint) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(point.date, format: .dateTime.month().day())
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(point.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 60, alignment: .leading)

            if point.gamesPlayed > 0 {
                HStack(spacing: 8) {
                    Label("\(point.totalActiveStreaks)", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Label("\(point.gamesPlayed)", systemImage: "gamecontroller.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    if point.gamesCompleted > 0 {
                        Label("\(point.gamesCompleted)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                }
            } else {
                Text("No activity")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(point.gamesPlayed > 0 ? Color.blue.opacity(0.05) : Color.clear)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDate = (selectedDate != nil && Calendar.current.isDate(selectedDate!, inSameDayAs: point.date)) ? nil : point.date
            }
            HapticManager.shared.trigger(.buttonTap)
        }
    }

    private var emptyActivityView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No daily activity to show")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
