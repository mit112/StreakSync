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

// MARK: - Save Error

/// Reasons an App Group write can fail. Surfaced so the confirmation sheet shows
/// the failure card instead of a false "Saved" when the write silently no-ops.
enum ShareSaveError: Error {
    case appGroupUnavailable
    case serializationFailed(underlying: Error)
}

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
        let result: GameResult
        do {
            result = try parser.parse(trimmed, for: game)
        } catch {
            setFailure("Couldn't parse your \(game.displayName) result. \(expectedFormatHint(for: game))")
            return
        }

        // Only reveal the success card once the App Group write is confirmed. If the
        // container is unresolvable or serialization fails, the write silently no-ops —
        // show the failure card rather than a false "Saved" (T1-1).
        do {
            try saveResult(result)
        } catch {
            logger.error("App Group save failed: \(error.localizedDescription, privacy: .public)")
            setFailure("Couldn't save to StreakSync. Open the app and add this result manually.")
            return
        }

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

    /// Persists a parsed result to App Group storage and posts the Darwin wake
    /// notification. Throws if the App Group container can't be resolved or the
    /// payload can't be serialized, so the caller can show a failure card instead
    /// of a false success (T1-1).
    private func saveResult(_ result: GameResult) throws {
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

        // Resolve the shared container up front — an optional here means the App Group
        // entitlement/provisioning is broken and every write below would no-op silently.
        guard let userDefaults = UserDefaults(suiteName: "group.com.mitsheth.StreakSync") else {
            logger.error("App Group container unavailable — result not saved")
            throw ShareSaveError.appGroupUnavailable
        }

        let data: Data
        let keysDataOut: Data
        do {
            data = try JSONSerialization.data(withJSONObject: sanitized, options: [])

            // 2) Key-based queue index (compute before writing anything)
            let resultKey = "gameResult_\(result.id.uuidString)"
            var resultKeys: [String] = []
            if let keysData = userDefaults.data(forKey: "gameResultKeys"),
               let existingKeys = try? JSONSerialization.jsonObject(with: keysData) as? [String] {
                resultKeys = existingKeys
            }
            resultKeys.append(resultKey)
            let maxQueueSize = 50
            if resultKeys.count > maxQueueSize {
                let keysToRemove = resultKeys.prefix(resultKeys.count - maxQueueSize)
                for key in keysToRemove {
                    userDefaults.removeObject(forKey: key)
                }
                resultKeys = Array(resultKeys.suffix(maxQueueSize))
            }
            keysDataOut = try JSONSerialization.data(withJSONObject: resultKeys, options: [])

            // 1) Latest result (backward compat + quick pickup)
            userDefaults.set(data, forKey: "latestGameResult")
            // 2) Key-based queue entry + index
            userDefaults.set(data, forKey: resultKey)
            userDefaults.set(keysDataOut, forKey: "gameResultKeys")
        } catch {
            logger.error("Failed to serialize result for App Group: \(error.localizedDescription, privacy: .public)")
            throw ShareSaveError.serializationFailed(underlying: error)
        }

        // 3) Timestamp
        userDefaults.set(Date(), forKey: "lastShareExtensionSave")

        // Flush cross-process writes before notifying the main app.
        userDefaults.synchronize()

        // 4) Darwin notification to wake the host app
        let darwinName = "com.streaksync.app.newResult" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinName),
            nil, nil, true
        )
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
        // Treat the hosted sheet as a modal and let VoiceOver dismiss it (§5.8).
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onDone() }
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
        // Opaque-ish material + a visible separator stroke (the old white 0.08
        // stroke vanished in light mode); align the radius to the app (§5.8).
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
    }
}

private struct ProcessingCard: View {
    // Parsing is local/synchronous, so a spinner would flash in and out. Only
    // reveal it if parsing somehow takes longer than a beat (§5.8).
    @State private var showSpinner = false

    var body: some View {
        VStack(spacing: 14) {
            ShareExtensionBrandMark(size: 40)
            if showSpinner {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Reading your result…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            showSpinner = true
        }
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

            // Scale with Dynamic Type and shrink to fit long scores like "1:23:45"
            // instead of a frozen 44pt (§5.8).
            Text(info.displayScore)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .foregroundStyle(info.completed ? Color.primary : Color.secondary)
                .padding(.vertical, 2)

            // Don't signal completion by color alone (§5.8 / a11y-color-not-sole).
            if !info.completed {
                Text("Did not finish")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
            .tint(Color.accentColor)
            .padding(.top, 6)
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
        .padding(.horizontal, 22)
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: "Saved to StreakSync")
        }
    }

    private var iconBadge: some View {
        ShareExtensionBrandMark(size: 64)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: info.iconSystemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(info.accentColor, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(.background, lineWidth: 2)
                    }
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

            Button("Close", action: onDone)
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
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: "Couldn't save. \(message)")
        }
    }
}
