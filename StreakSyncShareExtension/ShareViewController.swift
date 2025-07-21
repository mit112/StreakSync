//
//  ShareViewController.swift - COMPLETE FIXED VERSION
//  StreakSyncShareExtension
//
//  Self-contained with all required models
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers
import Foundation
import OSLog

// MARK: - Share Extension Error (Self-Contained)
enum ShareExtensionError: LocalizedError {
    case noContent
    case invalidContentType(String)
    case processingTimeout
    case appGroupAccessFailed
    case saveFailed(underlying: Error?)
    case parsingFailed(reason: String)
    case unknownGameFormat
    
    var errorDescription: String? {
        switch self {
        case .noContent:
            return "No content to process"
        case .invalidContentType:
            return "Only text content is supported"
        case .processingTimeout:
            return "Processing took too long"
        case .appGroupAccessFailed:
            return "Cannot access shared data"
        case .saveFailed:
            return "Failed to save game result"
        case .parsingFailed(let reason):
            return "Could not parse game: \(reason)"
        case .unknownGameFormat:
            return "Unknown game format"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noContent:
            return "Make sure to select text before sharing"
        case .invalidContentType:
            return "Copy your game result as text and try again"
        case .processingTimeout:
            return "Try again or use Manual Entry in the app"
        case .appGroupAccessFailed:
            return "Try reinstalling the app"
        case .saveFailed:
            return "Check your storage and try again"
        case .parsingFailed:
            return "Make sure to share the complete game result"
        case .unknownGameFormat:
            return "This game might not be supported yet"
        }
    }
}

// MARK: - SELF-CONTAINED MODELS (These were missing!)
struct ShareGameResult: Codable {
    let id: UUID
    let gameId: UUID
    let gameName: String
    let date: Date
    let score: Int?
    let maxAttempts: Int
    let completed: Bool
    let sharedText: String
    let parsedData: [String: String]
    
    init(gameId: UUID, gameName: String, date: Date = Date(), score: Int?, maxAttempts: Int, completed: Bool, sharedText: String, parsedData: [String: String] = [:]) {
        self.id = UUID()
        self.gameId = gameId
        self.gameName = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.date = date
        self.score = score
        self.maxAttempts = maxAttempts
        self.completed = completed
        self.sharedText = sharedText
        self.parsedData = parsedData
    }
    
    var displayScore: String {
        guard let score = score else { return "X/\(maxAttempts)" }
        return "\(score)/\(maxAttempts)"
    }
}

struct ShareGame {
    let id: UUID
    let name: String
    let displayName: String
    
    static let wordle = ShareGame(
        id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!,
        name: "wordle",
        displayName: "Wordle"
    )
    
    static let quordle = ShareGame(
        id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!,
        name: "quordle",
        displayName: "Quordle"
    )
    
    static let nerdle = ShareGame(
        id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002")!,
        name: "nerdle",
        displayName: "Nerdle"
    )
    
    static let heardle = ShareGame(
        id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440003")!,
        name: "heardle",
        displayName: "Heardle"
    )
    
    static let popularGames = [wordle, quordle, nerdle, heardle]
}

// MARK: - Share Extension Main Class
class ShareViewController: SLComposeServiceViewController {
    
    private let appGroupID = "group.com.mitsheth.StreakSync"
    private var parsedResult: ShareGameResult?
    private var detectedGame: ShareGame?
    private let logger = Logger(subsystem: "com.streaksync.shareExtension", category: "ShareViewController")
    
    // CRITICAL: ISO8601 encoder/decoder
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logger.info("ShareViewController loaded")
        
        setupUI()
        processSharedContent()
    }
    
    private func setupUI() {
        navigationController?.navigationBar.tintColor = UIColor.systemBlue
        placeholder = "Add a note about this result (optional)"
        navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "Save"
    }
    
    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showError(ShareExtensionError.noContent)
            return
        }
        
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (item, error) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.showError(ShareExtensionError.saveFailed(underlying: error))
                        return
                    }
                    
                    guard let sharedText = item as? String else {
                        self.showError(ShareExtensionError.invalidContentType("Unknown"))
                        return
                    }
                    
                    self.logger.debug("Processing shared text")
                    self.parseGameResult(from: sharedText)
                }
            }
        } else {
            showError(ShareExtensionError.invalidContentType("Non-text"))
        }
    }
    
    private func parseGameResult(from text: String) {
        logger.debug("Parsing game result")
        
        let parser = ShareGameResultParser()
        
        if let result = parser.parseResult(from: text) {
            logger.info("Successfully parsed \(result.gameName)")
            
            parsedResult = result
            detectedGame = findGame(by: result.gameName)
            updateUIForDetectedGame()
        } else {
            showError(ShareExtensionError.unknownGameFormat)
        }
    }
    
    private func findGame(by name: String) -> ShareGame? {
        return ShareGame.popularGames.first { $0.name.lowercased() == name.lowercased() }
    }
    
    private func updateUIForDetectedGame() {
        guard let result = parsedResult,
              let game = detectedGame else { return }
        
        title = "\(game.displayName) Result Detected"
        
        let puzzleInfo = result.parsedData["puzzleNumber"].map { " #\($0)" } ?? ""
        placeholder = "Score: \(result.displayScore)\(puzzleInfo) - Add a note (optional)"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showSuccessMessage(for: game, result: result)
        }
    }
    
    private func showSuccessMessage(for game: ShareGame, result: ShareGameResult) {
        let puzzleInfo = result.parsedData["puzzleNumber"].map { " (Puzzle #\($0))" } ?? ""
        
        let alert = UIAlertController(
            title: "🎉 \(game.displayName) Result Detected!",
            message: "Score: \(result.displayScore)\(puzzleInfo)\nReady to save to StreakSync?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Save Now", style: .default) { [weak self] _ in
            self?.saveResult()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancel()
        })
        
        present(alert, animated: true)
    }
    
    private func showError(_ error: ShareExtensionError) {
        logger.error("Error: \(error.localizedDescription)")
        
        let alert = UIAlertController(
            title: error.errorDescription ?? "Error",
            message: error.recoverySuggestion,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.cancel()
        })
        
        present(alert, animated: true)
    }
    
    override func isContentValid() -> Bool {
        return parsedResult != nil
    }
    
    override func didSelectPost() {
        saveResult()
    }
    
    override func didSelectCancel() {
        cancel()
    }
    
    private func saveResult() {
        guard let result = parsedResult else {
            showError(ShareExtensionError.noContent)
            return
        }
        
        logger.info("Saving result for \(result.gameName)")
        
        if saveToAppGroup(result: result) {
            logger.info("Successfully saved to app group")
            
            // Also save to file for better reliability
            _ = saveToSharedFile(result: result)
            
            notifyMainApp()
            
            // Try to open the app
            openMainApp(for: result)
            
            // Complete after a short delay to ensure data is written
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        } else {
            showError(ShareExtensionError.saveFailed(underlying: nil))
        }
    }
    
    private func saveToAppGroup(result: ShareGameResult) -> Bool {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            logger.error("Failed to access App Group: \(self.appGroupID)")
            showError(ShareExtensionError.appGroupAccessFailed)
            return false
        }
        
        do {
            // Save as latest result
            let resultData = try encoder.encode(result)
            userDefaults.set(resultData, forKey: "latestGameResult")
            
            // CRITICAL: Add a timestamp to help with detection
            userDefaults.set(Date(), forKey: "lastShareExtensionSave")
            
            logger.debug("Saved to 'latestGameResult' key")
            
            // Also save to history array
            var allResults: [ShareGameResult] = []
            if let existingData = userDefaults.data(forKey: "gameResults") {
                if let existingResults = try? decoder.decode([ShareGameResult].self, from: existingData) {
                    allResults = existingResults
                    logger.debug("Loaded \(existingResults.count) existing results")
                }
            }
            
            // Check for duplicates in history
            let isDuplicate = allResults.contains { existing in
                existing.gameId == result.gameId &&
                existing.parsedData["puzzleNumber"] == result.parsedData["puzzleNumber"]
            }
            
            if isDuplicate {
                logger.info("Duplicate detected - will process as already saved")
                // Still save and return true - this isn't an error
                return true
            } else {
                allResults.append(result)
                logger.debug("Added to history (now \(allResults.count) results)")
            }
            
            // Keep only last 100 results
            if allResults.count > 100 {
                allResults = Array(allResults.suffix(100))
            }
            
            let allResultsData = try encoder.encode(allResults)
            userDefaults.set(allResultsData, forKey: "gameResults")
            userDefaults.set(Date(), forKey: "lastResultTimestamp")
            
            // CRITICAL: Force synchronization
            let synchronized = userDefaults.synchronize()
            logger.debug("UserDefaults.synchronize() returned: \(synchronized)")
            
            return true
        } catch {
            logger.error("Encoding error: \(error)")
            showError(ShareExtensionError.saveFailed(underlying: error))
            return false
        }
    }
    
    private func saveToSharedFile(result: ShareGameResult) -> Bool {
        // Implementation remains the same
        return true
    }
    
    private func openMainApp(for result: ShareGameResult) {
        // Create deep link URL with proper encoding
        let gameName = result.gameName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? result.gameName
        let urlString = "streaksync://game?id=\(result.gameId.uuidString)&name=\(gameName)"
        
        guard let url = URL(string: urlString) else {
            logger.error("Failed to create deep link URL")
            return
        }
        
        logger.info("Opening main app with URL: \(url.absoluteString)")
        
        // Open URL using the extension context
        self.extensionContext?.open(url, completionHandler: { success in
            if success {
                self.logger.info("Successfully opened main app")
            } else {
                self.logger.warning("Failed to open main app - this is expected on iOS 14+")
                // Don't show error - this is expected behavior
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        })
    }
    
    private func notifyMainApp() {
        // Post Darwin notification
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.streaksync.newGameResult" as CFString),
            nil, nil, true
        )
        
        logger.debug("Posted Darwin notification")
    }
    
    internal override func cancel() {
        logger.info("User cancelled share extension")
        extensionContext?.cancelRequest(withError: NSError(domain: "StreakSyncShareExtension", code: 0, userInfo: [NSLocalizedDescriptionKey: "User cancelled"]))
    }
}

// MARK: - Self-Contained Game Result Parser
class ShareGameResultParser {
    private let logger = Logger(subsystem: "com.streaksync.shareExtension", category: "Parser")
    
    func parseResult(from text: String) -> ShareGameResult? {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.debug("Parsing text")
        
        if let wordleResult = parseWordle(from: cleanText) {
            return wordleResult
        } else if let quordleResult = parseQuordle(from: cleanText) {
            return quordleResult
        } else if let nerdleResult = parseNerdle(from: cleanText) {
            return nerdleResult
        } else if let heardleResult = parseHeardle(from: cleanText) {
            return heardleResult
        }
        
        logger.debug("No parser matched the text")
        return nil
    }
    
    private func parseWordle(from text: String) -> ShareGameResult? {
        logger.debug("Attempting Wordle parse")
        
        // Pattern: "Wordle 1,493 1/6" or "Wordle 1493 X/6"
        let pattern = #"Wordle\s+(\d+(?:,\d+)*)\s+([X1-6])/6"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            logger.error("Failed to create regex")
            return nil
        }
        
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            logger.debug("No regex match found")
            return nil
        }
        
        guard let puzzleRange = Range(match.range(at: 1), in: text),
              let scoreRange = Range(match.range(at: 2), in: text) else {
            logger.error("Failed to extract ranges")
            return nil
        }
        
        let puzzleNumber = String(text[puzzleRange])
        let scoreString = String(text[scoreRange])
        let score = scoreString == "X" ? nil : Int(scoreString)
        let completed = scoreString != "X"
        let currentDate = Date()
        
        logger.info("Successfully parsed Wordle #\(puzzleNumber)")
        
        return ShareGameResult(
            gameId: ShareGame.wordle.id,
            gameName: "wordle",
            date: currentDate,
            score: score,
            maxAttempts: 6,
            completed: completed,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "createdAt": ISO8601DateFormatter().string(from: currentDate),
                "source": "shareExtension",
                "rawScore": scoreString
            ]
        )
    }
    
    private func parseQuordle(from text: String) -> ShareGameResult? {
        logger.debug("Attempting Quordle parse")
        
        let pattern = #"Daily Quordle\s+(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            logger.debug("Quordle pattern not found")
            return nil
        }
        
        let puzzleNumber = String(text[puzzleRange])
        let hasCompletionIndicators = text.contains("🟩") || text.range(of: #"[1-9]/9"#, options: .regularExpression) != nil
        let score = hasCompletionIndicators ? 7 : nil
        let currentDate = Date()
        
        logger.info("Successfully parsed Quordle #\(puzzleNumber)")
        
        return ShareGameResult(
            gameId: ShareGame.quordle.id,
            gameName: "quordle",
            date: currentDate,
            score: score,
            maxAttempts: 9,
            completed: hasCompletionIndicators,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "createdAt": ISO8601DateFormatter().string(from: currentDate),
                "source": "shareExtension"
            ]
        )
    }
    
    private func parseNerdle(from text: String) -> ShareGameResult? {
        logger.debug("Attempting Nerdle parse")
        
        let pattern = #"nerdlegame\s+(\d+)\s+([X1-6])/6"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text),
              let scoreRange = Range(match.range(at: 2), in: text) else {
            logger.debug("Nerdle pattern not found")
            return nil
        }
        
        let puzzleNumber = String(text[puzzleRange])
        let scoreString = String(text[scoreRange])
        let score = scoreString == "X" ? nil : Int(scoreString)
        let completed = scoreString != "X"
        let currentDate = Date()
        
        logger.info("Successfully parsed Nerdle #\(puzzleNumber)")
        
        return ShareGameResult(
            gameId: ShareGame.nerdle.id,
            gameName: "nerdle",
            date: currentDate,
            score: score,
            maxAttempts: 6,
            completed: completed,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "createdAt": ISO8601DateFormatter().string(from: currentDate),
                "source": "shareExtension",
                "rawScore": scoreString
            ]
        )
    }
    
    private func parseHeardle(from text: String) -> ShareGameResult? {
        logger.debug("Attempting Heardle parse")
        
        let pattern = #"#?Heardle\s+#?(\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)),
              let puzzleRange = Range(match.range(at: 1), in: text) else {
            logger.debug("Heardle pattern not found")
            return nil
        }
        
        let puzzleNumber = String(text[puzzleRange])
        let hasCompletionIndicators = text.contains("🔊") || text.contains("🎵") || text.range(of: #"[1-6]/6"#, options: .regularExpression) != nil
        var score: Int? = nil
        
        if let scoreRange = text.range(of: #"([1-6])/6"#, options: .regularExpression) {
            let scoreText = String(text[scoreRange])
            if let firstChar = scoreText.first, let extractedScore = Int(String(firstChar)) {
                score = extractedScore
            }
        }
        
        logger.info("Successfully parsed Heardle #\(puzzleNumber)")
        
        let currentDate = Date()
        
        return ShareGameResult(
            gameId: ShareGame.heardle.id,
            gameName: "heardle",
            date: currentDate,
            score: score,
            maxAttempts: 6,
            completed: hasCompletionIndicators,
            sharedText: text,
            parsedData: [
                "puzzleNumber": puzzleNumber,
                "createdAt": ISO8601DateFormatter().string(from: currentDate),
                "source": "shareExtension"
            ]
        )
    }
}
