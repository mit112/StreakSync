//
//  PersistenceService+Archive.swift
//  StreakSync
//
//  Non-destructive alternative to clearAll: namespaced local archive and restore
//

import Foundation
import OSLog

extension UserDefaultsPersistenceService {
    private static let archiveLogger = Logger(subsystem: "com.streaksync.app", category: "PersistenceArchive")

    private static var archivedKeys: [String] {
        [Keys.gameResults, Keys.achievements, Keys.streaks, Keys.deletedResultIds]
    }

    /// Namespaces are Firebase UIDs, which are alphanumeric — but never trust that
    /// enough to build a UserDefaults key or a filename out of one unsanitised.
    private static func sanitize(_ namespace: String) -> String {
        let allowed = namespace.filter { $0.isLetter || $0.isNumber }
        return allowed.isEmpty ? "unknown" : String(allowed.prefix(64))
    }

    private static func archiveKey(for key: String, namespace: String) -> String {
        "\(key)__archived_\(sanitize(namespace))"
    }

    private func archivedResultsURL(namespace: String) -> URL {
        gameResultsFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("game_results_archived_\(Self.sanitize(namespace)).json")
    }

    /// Moves every persisted key into a namespaced archive instead of deleting it.
    ///
    /// An account switch used to call `clearAll()`, which is irreversible. The switch
    /// that actually happens to people is signing in with a provider they have never
    /// used before, which silently mints a fresh empty Firebase account — and their
    /// streaks were simply gone, with no error and no warning. Archiving costs a few
    /// hundred kilobytes and makes every misclassification recoverable, including the
    /// ones no detector catches.
    ///
    /// One archive per namespace: archiving again overwrites it.
    func archiveAll(namespace: String) {
        var moved = 0
        for key in Self.archivedKeys where key != Keys.gameResults {
            guard let data = userDefaults.data(forKey: key) else { continue }
            userDefaults.set(data, forKey: Self.archiveKey(for: key, namespace: namespace))
            userDefaults.removeObject(forKey: key)
            moved += 1
        }

        let archiveURL = archivedResultsURL(namespace: namespace)
        if FileManager.default.fileExists(atPath: gameResultsFileURL.path) {
            try? FileManager.default.removeItem(at: archiveURL)
            do {
                try FileManager.default.moveItem(at: gameResultsFileURL, to: archiveURL)
                moved += 1
            } catch {
                // A failed move must not silently degrade into a delete — leave the
                // results in place rather than lose them.
                Self.archiveLogger.error("Archiving results file failed: \(error.localizedDescription)")
            }
        }
        Self.archiveLogger.info("Archived \(moved) store(s) under a namespaced backup")
    }

    /// True when a previous session's data is still recoverable for `namespace`.
    func hasArchive(namespace: String) -> Bool {
        let hasKeys = Self.archivedKeys.contains { key in
            key != Keys.gameResults
                && userDefaults.data(forKey: Self.archiveKey(for: key, namespace: namespace)) != nil
        }
        return hasKeys || FileManager.default.fileExists(atPath: archivedResultsURL(namespace: namespace).path)
    }

    /// Moves a namespaced archive back into the live stores, replacing whatever is
    /// there. Returns true when anything was restored.
    ///
    /// This is what makes signing back in with the original provider actually give the
    /// user their streaks back, without waiting on — or depending on — a cloud pull.
    @discardableResult
    func restoreArchive(namespace: String) -> Bool {
        var restored = 0
        for key in Self.archivedKeys where key != Keys.gameResults {
            let archived = Self.archiveKey(for: key, namespace: namespace)
            guard let data = userDefaults.data(forKey: archived) else { continue }
            userDefaults.set(data, forKey: key)
            userDefaults.removeObject(forKey: archived)
            restored += 1
        }

        let archiveURL = archivedResultsURL(namespace: namespace)
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try? FileManager.default.removeItem(at: gameResultsFileURL)
            do {
                try FileManager.default.moveItem(at: archiveURL, to: gameResultsFileURL)
                restored += 1
            } catch {
                Self.archiveLogger.error("Restoring results file failed: \(error.localizedDescription)")
            }
        }
        Self.archiveLogger.info("Restored \(restored) store(s) from a namespaced backup")
        return restored > 0
    }
}
