//
//  ShareViewController.swift
//  StreakSyncShareExtension
//
//  Receives shared text from other apps, detects the game, parses
//  the result using the shared GameResultParser, and saves it to
//  App Group storage for the main app to ingest.
//

import UIKit
import UniformTypeIdentifiers
import Foundation

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Processing..."
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        processContent()
    }
    
    // MARK: - Content Extraction
    
    private func processContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showResult("No content")
            return
        }
        
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (rawItem, error) in
                let text: String? = {
                    if let s = rawItem as? String { return s }
                    if let data = rawItem as? Data, let s = String(data: data, encoding: .utf8) { return s }
                    return nil
                }()
                DispatchQueue.main.async {
                    if let text = text {
                        self?.processText(text)
                    } else {
                        self?.showResult("Couldn't process text")
                    }
                }
            }
        } else {
            showResult("Unsupported content type")
        }
    }
    
    // MARK: - Game Detection & Parsing
    
    private func processText(_ text: String) {
        // Input sanitization: reject oversized input
        guard text.count <= 5000 else {
            showResult("Text too long to process")
            return
        }
        
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Detect which game this result belongs to
        guard let game = detectGame(from: text) else {
            showResult("Game not recognized. Supported games include Wordle, Connections, Strands, and more. Open StreakSync to add results manually.")
            return
        }

        // Parse using the shared GameResultParser (same logic as main app)
        let parser = GameResultParser()
        do {
            let result = try parser.parse(text, for: game)
            saveResult(result)
            showResult("✓ \(game.displayName) result saved!")
        } catch {
            let hint = expectedFormatHint(for: game)
            showResult("Couldn't parse your \(game.displayName) result. \(hint)")
        }
    }
    
    /// Maps shared text to a Game by delegating to the shared GameDetector.
    private func detectGame(from text: String) -> Game? {
        GameDetector.detect(from: text, in: Game.allAvailableGames)
    }

    /// Returns a short hint about the expected share text format for a game.
    /// Only games with distinctive share formats get custom hints; all others
    /// fall through to the generic default. Update when adding new games.
    private func expectedFormatHint(for game: Game) -> String {
        switch game.name {
        case "wordle":
            return "Expected format: \"Wordle 1,234 4/6\" followed by emoji grid."
        case "connections":
            return "Expected format: \"Connections\" with \"Puzzle #123\" and colored squares."
        case "strands":
            return "Expected format: \"Strands #123\" with hint count."
        case "quordle":
            return "Expected format: \"Daily Quordle 123\" with score digits."
        default:
            return "Make sure you're sharing the full result text from the game."
        }
    }
    
    // MARK: - Input Sanitization
    
    private func sanitizeResult(_ dict: [String: Any]) -> [String: Any] {
        var sanitized = dict
        if let text = sanitized["sharedText"] as? String, text.count > 2000 {
            sanitized["sharedText"] = String(text.prefix(2000))
        }
        if var parsedData = sanitized["parsedData"] as? [String: String] {
            for (key, value) in parsedData {
                if value.count > 500 {
                    parsedData[key] = String(value.prefix(500))
                }
            }
            sanitized["parsedData"] = parsedData
        }
        return sanitized
    }
    
    // MARK: - Persistence
    
    private func saveResult(_ result: GameResult) {
        // Convert GameResult to JSON dictionary for App Group storage
        let dict: [String: Any] = {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var d: [String: Any] = [
                "id": result.id.uuidString,
                "gameId": result.gameId.uuidString,
                "gameName": result.gameName,
                "date": isoFormatter.string(from: result.date),
                "lastModified": isoFormatter.string(from: result.lastModified),
                "maxAttempts": result.maxAttempts,
                "completed": result.completed,
                "sharedText": result.sharedText,
                "parsedData": result.parsedData
            ]
            if let score = result.score {
                d["score"] = score
            }
            d["parsedData"] = (d["parsedData"] as? [String: String] ?? [:])
                .merging(["source": "shareExtension"]) { _, new in new }
            return d
        }()
        
        let sanitized = sanitizeResult(dict)
        
        do {
            let data = try JSONSerialization.data(withJSONObject: sanitized, options: [])
            let userDefaults = UserDefaults(suiteName: "group.com.mitsheth.StreakSync")
            
            // 1) Latest result (backward compat + quick pickup)
            userDefaults?.set(data, forKey: "latestGameResult")
            
            // 2) Key-based queue
            let resultId = result.id.uuidString
            let resultKey = "gameResult_\(resultId)"
            userDefaults?.set(data, forKey: resultKey)
            
            var resultKeys: [String] = []
            if let keysData = userDefaults?.data(forKey: "gameResultKeys"),
               let existingKeys = try? JSONSerialization.jsonObject(with: keysData) as? [String] {
                resultKeys = existingKeys
            }
            resultKeys.append(resultKey)
            // Cap queue at 50 entries to prevent unbounded growth
            let maxQueueSize = 50
            if resultKeys.count > maxQueueSize {
                let keysToRemove = resultKeys.prefix(resultKeys.count - maxQueueSize)
                for key in keysToRemove {
                    userDefaults?.removeObject(forKey: key)
                }
                resultKeys = Array(resultKeys.suffix(maxQueueSize))
            }
            let keysDataOut = try JSONSerialization.data(withJSONObject: resultKeys, options: [])
            userDefaults?.set(keysDataOut, forKey: "gameResultKeys")
            
            // 3) Timestamp
            userDefaults?.set(Date(), forKey: "lastShareExtensionSave")

            // Flush writes to shared container before notifying the main app.
            // Cross-process UserDefaults requires explicit synchronize() to ensure
            // the main app reads the latest data when woken by the Darwin notification.
            userDefaults?.synchronize()

            // 4) Darwin notification
            let darwinName = "com.streaksync.app.newResult" as CFString
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(darwinName),
                nil, nil, true
            )
        } catch {
            // Best-effort — silently fail
        }
    }
    
    // MARK: - UI
    
    private func showResult(_ message: String) {
        let alert = UIAlertController(title: "StreakSync", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        present(alert, animated: true)
    }
}
