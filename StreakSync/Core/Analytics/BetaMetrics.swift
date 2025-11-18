//
//  BetaMetrics.swift
//  StreakSync
//
//  Lightweight logging for beta rollout checkpoints.
//

import Foundation
import OSLog

enum BetaMetricEvent: String {
    case inviteLinkCreated
    case inviteLinkFailed
    case feedbackSubmitted
}

struct BetaMetrics {
    private static let logger = Logger(subsystem: "com.streaksync.app", category: "BetaMetrics")

    static func track(_ event: BetaMetricEvent, properties: [String: String] = [:]) {
        var merged = properties
        merged["event"] = event.rawValue
        merged["timestamp"] = ISO8601DateFormatter().string(from: Date())
        logger.info("\(merged, privacy: .public)")
    }
}

