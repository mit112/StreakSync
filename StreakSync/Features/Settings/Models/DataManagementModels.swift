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

    /// Puzzle-numbered results are dated at local noon on their puzzle day (see
    /// `GameResultParser.canonicalPuzzleDate`), so this morning's Wordle is legitimately
    /// "in the future" until midday. Rejecting any future date refused a same-morning
    /// backup outright; this allows the same slack the parser's own guard does.
    static let futureDateTolerance: TimeInterval = 36 * 3600

    func validate(now: Date = Date()) throws {
        if version > 1 {
            throw ImportError.invalidVersion
        }

        let latestPlausible = now.addingTimeInterval(Self.futureDateTolerance)
        for result in gameResults where result.gameName.isEmpty || result.date > latestPlausible {
            throw ImportError.corruptedData
        }
    }
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
