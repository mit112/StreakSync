//
//  ShareViewController.swift
//  StreakSyncShareExtension
//
//  Receives shared text from other apps, detects the game, parses
//  the result using the shared GameResultParser, and saves it to
//  App Group storage for the main app to ingest. Presents a SwiftUI
//  confirmation sheet instead of a system UIAlertController.
//

import Foundation
import OSLog
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - View Model

@MainActor
final class ShareResultViewModel: ObservableObject {
    enum State {
        case processing
        case success(SuccessInfo)
        case failure(message: String)
    }

    struct SuccessInfo {
        let gameId: String
        let displayName: String
        let iconSystemName: String
        let accentColor: Color
        let displayScore: String
        let completed: Bool
    }

    @Published var state: State = .processing
}

// MARK: - View Controller

class ShareViewController: UIViewController {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "ShareExtension")
    private let viewModel = ShareResultViewModel()
    private var hostingController: UIHostingController<ShareResultRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        embedSwiftUIHost()
        processContent()
    }

    // MARK: - SwiftUI Host

    private func embedSwiftUIHost() {
        let rootView = ShareResultRootView(
            viewModel: viewModel,
            onDone: { [weak self] in self?.dismissExtension(primingDeepLinkGameId: nil) },
            onViewInApp: { [weak self] gameId in self?.dismissExtension(primingDeepLinkGameId: gameId) }
        )
        let host = UIHostingController(rootView: rootView)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    /// Dismisses the share extension. If a gameId is provided, primes the
    /// App Group "pending deep link" key so the main app routes to that game
    /// on its next activation (notification tap, icon, etc.).
    private func dismissExtension(primingDeepLinkGameId gameId: String?) {
        if let gameId = gameId {
            logger.info("View in App tapped — priming deep link to: \(gameId, privacy: .public)")
            let defaults = UserDefaults(suiteName: "group.com.mitsheth.StreakSync")
            defaults?.set(gameId, forKey: "pendingDeepLinkGameId")
            defaults?.synchronize()
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    // MARK: - Content Extraction

    private func processContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            setFailure("No shareable content found.")
            return
        }

        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                let text: String? = {
                    if let s = item as? String { return s }
                    if let data = item as? Data, let s = String(data: data, encoding: .utf8) { return s }
                    return nil
                }()
                DispatchQueue.main.async {
                    if let text = text {
                        self?.processText(text)
                    } else {
                        self?.setFailure("Couldn't read the shared text.")
                    }
                }
            }
        } else {
            setFailure("Unsupported content — only text results can be imported.")
        }
    }

    // MARK: - Game Detection & Parsing

    private func processText(_ text: String) {
        guard text.count <= 5000 else {
            setFailure("That share is unusually large — try copying just the result text.")
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let game = detectGame(from: trimmed) else {
            setFailure(
                "Game not recognized. Supported games include Wordle, Connections, Strands, and more. " +
                "Open StreakSync to add this result manually."
            )
            return
        }

        let parser = GameResultParser()
        do {
            let result = try parser.parse(trimmed, for: game)
            saveResult(result)
            let info = ShareResultViewModel.SuccessInfo(
                gameId: result.gameId.uuidString,
                displayName: game.displayName,
                iconSystemName: game.iconSystemName,
                accentColor: game.backgroundColor.color,
                displayScore: Self.formattedDisplayScore(for: result),
                completed: result.completed
            )
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                viewModel.state = .success(info)
            }
        } catch {
            setFailure("Couldn't parse your \(game.displayName) result. \(expectedFormatHint(for: game))")
        }
    }

    private func setFailure(_ message: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.state = .failure(message: message)
        }
    }

    private func detectGame(from text: String) -> Game? {
        GameDetector.detect(from: text, in: Game.allAvailableGames)
    }

    private func expectedFormatHint(for game: Game) -> String {
        switch game.name {
        case "wordle":
            return "Expected: \"Wordle 1,234 4/6\" followed by the emoji grid."
        case "connections":
            return "Expected: \"Connections\" with \"Puzzle #123\" and colored squares."
        case "strands":
            return "Expected: \"Strands #123\" with the hint count."
        case "quordle":
            return "Expected: \"Daily Quordle 123\" with score digits."
        default:
            return "Make sure you're sharing the full result text from the game."
        }
    }

    /// Computes a human-friendly score string. Prefers a parser-provided
    /// `displayScore` (e.g. "3 hints", "1:24"), falls back to `score/max`,
    /// then to a completion flag.
    private static func formattedDisplayScore(for result: GameResult) -> String {
        if let provided = result.parsedData["displayScore"], !provided.isEmpty {
            return provided
        }
        if let score = result.score, result.maxAttempts > 0 {
            return "\(score)/\(result.maxAttempts)"
        }
        return result.completed ? "Solved" : "Did not solve"
    }

    // MARK: - Input Sanitization

    private func sanitizeResult(_ dict: [String: Any]) -> [String: Any] {
        var sanitized = dict
        if let text = sanitized["sharedText"] as? String, text.count > 2000 {
            sanitized["sharedText"] = String(text.prefix(2000))
        }
        if var parsedData = sanitized["parsedData"] as? [String: String] {
            for (key, value) in parsedData where value.count > 500 {
                parsedData[key] = String(value.prefix(500))
            }
            sanitized["parsedData"] = parsedData
        }
        return sanitized
    }

    // MARK: - Persistence

    private func saveResult(_ result: GameResult) {
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
            let resultKey = "gameResult_\(result.id.uuidString)"
            userDefaults?.set(data, forKey: resultKey)

            var resultKeys: [String] = []
            if let keysData = userDefaults?.data(forKey: "gameResultKeys"),
               let existingKeys = try? JSONSerialization.jsonObject(with: keysData) as? [String] {
                resultKeys = existingKeys
            }
            resultKeys.append(resultKey)
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

            // Flush cross-process writes before notifying the main app.
            userDefaults?.synchronize()

            // 4) Darwin notification to wake the host app
            let darwinName = "com.streaksync.app.newResult" as CFString
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(darwinName),
                nil, nil, true
            )
        } catch {
            logger.error("Failed to serialize result for App Group: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - SwiftUI Result View

struct ShareResultRootView: View {
    @ObservedObject var viewModel: ShareResultViewModel
    let onDone: () -> Void
    let onViewInApp: (String) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDone() }

            card
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var card: some View {
        Group {
            switch viewModel.state {
            case .processing:
                ProcessingCard()
            case .success(let info):
                SuccessCard(info: info, onDone: { onViewInApp(info.gameId) })
            case .failure(let message):
                FailureCard(message: message, onDone: onDone)
            }
        }
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
    }
}

private struct ProcessingCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Reading your result…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

private struct SuccessCard: View {
    let info: ShareResultViewModel.SuccessInfo
    /// Done dismisses the extension and primes the deep link so the next
    /// time the user opens the app (via notification or icon) they land on
    /// the game detail.
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            iconBadge
                .padding(.top, 4)

            Text(info.displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(info.displayScore)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(info.completed ? Color.primary : Color.secondary)
                .padding(.vertical, 2)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved to StreakSync")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)

            Button(action: onDone) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(info.accentColor)
            .padding(.top, 6)
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
        .padding(.horizontal, 22)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(info.accentColor.opacity(0.18))
                .frame(width: 64, height: 64)
            Image(systemName: info.iconSystemName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(info.accentColor)
        }
    }
}

private struct FailureCard: View {
    let message: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.top, 4)

            Text("Couldn't save")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("OK", action: onDone)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
        .padding(.horizontal, 22)
    }
}
