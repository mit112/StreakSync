//
//  DataManagementModels.swift
//  StreakSync
//
//  Supporting types for data export/import — ExportData, ImportError, ShareSheet
//

import SwiftUI

// MARK: - Import Errors
enum ImportError: LocalizedError {
    case invalidVersion
    case corruptedData
    case cannotAccessFile

    var errorDescription: String? {
        switch self {
        case .invalidVersion:
            return "Incompatible backup version"
        case .corruptedData:
            return "Corrupted backup data"
        case .cannotAccessFile:
            return "Cannot access file"
        }
    }
}

// MARK: - Enhanced Export Data Model
struct ExportData: Codable {
    let version: Int
    let exportDate: Date
    let appVersion: String
    let gameResults: [GameResult]
    let achievements: [TieredAchievement]
    let streaks: [GameStreak]
    let favoriteGameIds: [UUID]
    let customGames: [Game]
}

// MARK: - Share Sheet (for Export)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
