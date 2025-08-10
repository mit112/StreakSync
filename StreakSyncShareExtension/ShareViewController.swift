//
//  ShareViewController.swift - WORKING VERSION
//  StreakSyncShareExtension
//
//  Simple UIViewController without SLComposeServiceViewController
//

import UIKit
import UniformTypeIdentifiers
import Foundation
import OSLog

class ShareViewController: UIViewController {
    
    private let appGroupID = "group.com.mitsheth.StreakSync"
    private let logger = Logger(subsystem: "com.streaksync.shareExtension", category: "ShareViewController")
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Minimal iOS-style background
        view.backgroundColor = .clear
        
        // Create blur effect background
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
        
        // Process content
        processSharedContent()
    }
    
    private func processSharedContent() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            showResult(success: false, gameName: nil)
            return
        }
        
        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (text, error) in
                DispatchQueue.main.async {
                    if let sharedText = text as? String {
                        self?.handleText(sharedText)
                    } else {
                        self?.showResult(success: false, gameName: nil)
                    }
                }
            }
        } else {
            showResult(success: false, gameName: nil)
        }
    }
    
    private func handleText(_ text: String) {
        let parser = ShareGameResultParser()
        
        guard let result = parser.parseResult(from: text) else {
            showResult(success: false, gameName: nil)
            return
        }
        
        // Save to app group
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            showResult(success: false, gameName: result.gameName)
            return
        }
        
        do {
            let data = try encoder.encode(result)
            userDefaults.set(data, forKey: "latestGameResult")
            userDefaults.set(Date(), forKey: "lastShareExtensionSave")
            userDefaults.synchronize()
            
            // Notify main app
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("com.streaksync.app.newResult" as CFString),
                nil, nil, true
            )
            
            // Show success
            showResult(success: true, gameName: result.gameName)
            
        } catch {
            showResult(success: false, gameName: result.gameName)
        }
    }
    
    private func showResult(success: Bool, gameName: String?) {
        // Create the toast container
        let toastContainer = UIView()
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.backgroundColor = .clear
        
        // Create the toast content
        let toast = UIView()
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.backgroundColor = .systemBackground
        toast.layer.cornerRadius = 20
        toast.layer.shadowColor = UIColor.black.cgColor
        toast.layer.shadowOpacity = 0.1
        toast.layer.shadowOffset = CGSize(width: 0, height: 2)
        toast.layer.shadowRadius = 8
        
        // Icon and label stack
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let icon = UIImageView()
        icon.preferredSymbolConfiguration = iconConfig
        
        if success {
            icon.image = UIImage(systemName: "checkmark.circle.fill")
            icon.tintColor = .systemGreen
        } else {
            icon.image = UIImage(systemName: "exclamationmark.triangle.fill")
            icon.tintColor = .systemOrange
        }
        
        // Label
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        
        if success {
            let game = gameName?.capitalized ?? "Result"
            label.text = "\(game) saved"
        } else {
            label.text = "Couldn't save"
        }
        
        stackView.addArrangedSubview(icon)
        stackView.addArrangedSubview(label)
        
        toast.addSubview(stackView)
        toastContainer.addSubview(toast)
        view.addSubview(toastContainer)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Container fills the view
            toastContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toastContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toastContainer.topAnchor.constraint(equalTo: view.topAnchor),
            toastContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Toast centered
            toast.centerXAnchor.constraint(equalTo: toastContainer.centerXAnchor),
            toast.centerYAnchor.constraint(equalTo: toastContainer.centerYAnchor),
            
            // Stack inside toast
            stackView.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: toast.topAnchor, constant: 14),
            stackView.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -14)
        ])
        
        // Haptic feedback
        if success {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } else {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
        }
        
        // Animate in
        toast.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        toast.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            toast.transform = .identity
            toast.alpha = 1
        }
        
        // Dismiss after delay
        let dismissDelay = success ? 0.7 : 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) { [weak self] in
            UIView.animate(withDuration: 0.2, animations: {
                toast.alpha = 0
                toast.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }) { _ in
                if success {
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                } else {
                    self?.extensionContext?.cancelRequest(withError: NSError(
                        domain: "StreakSync",
                        code: 1,
                        userInfo: nil
                    ))
                }
            }
        }
    }
}

// MARK: - Self-Contained Game Result Parser
class ShareGameResultParser {
    private let logger = Logger(subsystem: "com.streaksync.shareExtension", category: "Parser")
    
    func parseResult(from text: String) -> GameResult? {  // ← Returns shared GameResult
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
    
    private func parseWordle(from text: String) -> GameResult? {
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
        
        return GameResult(  // ← Using shared GameResult
            gameId: Game.wordle.id,  // ← Using Game.wordle from SharedModels
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
    
    private func parseQuordle(from text: String) -> GameResult? {
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
        
        return GameResult(
            gameId: Game.quordle.id,  // ← Using Game.quordle from SharedModels
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
    
    private func parseNerdle(from text: String) -> GameResult? {
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
        
        return GameResult(
            gameId: Game.nerdle.id,  // ← Using Game.nerdle from SharedModels
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
    
    private func parseHeardle(from text: String) -> GameResult? {
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
        
        return GameResult(
            gameId: Game.heardle.id,  // ← Using Game.heardle from SharedModels
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
