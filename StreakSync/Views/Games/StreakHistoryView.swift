//
//  StreakHistoryView.swift
//  StreakSync
//
//  Simplified streak history with clean calendar view
//

import SwiftUI

// MARK: - Streak History View
struct StreakHistoryView: View {
    let streak: GameStreak
    @Environment(AppState.self) private var appState
    @State private var selectedMonth = Date()
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    private var monthResults: [GameResult] {
        let calendar = Calendar.current
        let month = calendar.dateInterval(of: .month, for: selectedMonth)!
        
        return appState.recentResults
            .filter { $0.gameId == streak.gameId }
            .filter { month.contains($0.date) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Stats header
                statsHeader
                
                // Month navigation
                monthNavigation
                
                // Calendar grid
                calendarGrid
                
                // Month summary
                if !monthResults.isEmpty {
                    monthSummary
                }
            }
            .padding()
        }
        .navigationTitle(streak.gameName.capitalized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Stats Header
    private var statsHeader: some View {
        HStack(spacing: Spacing.lg) {
            StatBox(
                value: "\(streak.currentStreak)",
                label: "Current",
                color: .green
            )
            
            StatBox(
                value: "\(streak.maxStreak)",
                label: "Best",
                color: .orange
            )
            
            StatBox(
                value: streak.completionPercentage,
                label: "Success",
                color: .blue
            )
        }
    }
    
    // MARK: - Month Navigation
    private var monthNavigation: some View {
        HStack {
            Button {
                withAnimation {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth)!
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            
            Spacer()
            
            Button {
                withAnimation {
                    if Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month) == false {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth)!
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.blue)
            }
            .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
        }
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        VStack(spacing: Spacing.sm) {
            // Weekday headers
            HStack(spacing: Spacing.xs) {
                ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7), spacing: Spacing.xs) {
                ForEach(calendarDays(), id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            result: result(for: date),
                            gameColor: game?.backgroundColor.color ?? .gray
                        )
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
    }
    
    // MARK: - Month Summary
    private var monthSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Month Summary")
                .font(.headline)
            
            HStack {
                Label("\(monthResults.count) games played", systemImage: "gamecontroller")
                    .font(.subheadline)
                
                Spacer()
                
                Label("\(monthResults.filter(\.completed).count) completed", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
    }
    
    // MARK: - Helper Methods
    private func calendarDays() -> [Date?] {
        let calendar = Calendar.current
        let month = calendar.dateInterval(of: .month, for: selectedMonth)!
        let firstWeekday = calendar.component(.weekday, from: month.start)
        let numberOfDays = calendar.range(of: .day, in: .month, for: selectedMonth)!.count
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: month.start) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func result(for date: Date) -> GameResult? {
        let calendar = Calendar.current
        return monthResults.first { result in
            calendar.isDate(result.date, inSameDayAs: date)
        }
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let result: GameResult?
    let gameColor: Color
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: isToday ? 2 : 0)
                )
            
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(textColor)
        }
        .frame(height: 44)
    }
    
    private var backgroundColor: Color {
        if let result = result {
            return result.completed ? gameColor.opacity(0.2) : Color(.systemGray6)
        }
        return Color.clear
    }
    
    private var borderColor: Color {
        isToday ? .blue : .clear
    }
    
    private var textColor: Color {
        result != nil ? .primary : .secondary
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StreakHistoryView(
            streak: GameStreak(
                gameId: UUID(),
                gameName: "wordle",
                currentStreak: 15,
                maxStreak: 23,
                totalGamesPlayed: 100,
                totalGamesCompleted: 85,
                lastPlayedDate: Date(),
                streakStartDate: Date().addingTimeInterval(-15 * 24 * 60 * 60)
            )
        )
        .environment(AppState())
    }
}
