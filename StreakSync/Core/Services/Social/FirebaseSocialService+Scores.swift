//
//  FirebaseSocialService+Scores.swift
//  StreakSync
//
//  Score publishing, flushing, and reconciliation logic for FirebaseSocialService.
//

import FirebaseFirestore
import Foundation

// MARK: - Allowed Readers

extension FirebaseSocialService {

    /// Returns [self] + [accepted friend IDs] for the `allowedReaders` field on score documents.
    /// Uses the cached friends list (60s TTL) to avoid redundant Firestore reads.
    /// Falls back to [self] if friends can't be fetched (e.g., offline).
    private func currentAllowedReaders() async -> [String] {
        guard let uid = uid else { return [] }
        do {
            let friends = try await listFriends()
            return [uid] + friends.map(\.id)
        } catch {
 logger.warning("Failed to fetch friends for allowedReaders, using self only")
            return [uid]
        }
    }

    /// Builds the Firestore data dictionary for a score document.
    /// Conditionally includes `score` and `currentStreak` only when non-nil
    /// to avoid writing NSNull which violates the security rules' `is int` check.
    private func scoreDocData(
        userId: String,
        score: DailyGameScore,
        allowedReaders: [String]
    ) -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "gameId": score.gameId.uuidString,
            "gameName": score.gameName,
            "dateInt": score.dateInt,
            "maxAttempts": score.maxAttempts,
            "completed": score.completed,
            "allowedReaders": allowedReaders,
            "publishedAt": FieldValue.serverTimestamp()
        ]
        if let scoreValue = score.score {
            data["score"] = scoreValue
        }
        if let streak = score.currentStreak {
            data["currentStreak"] = streak
        }
        return data
    }

    // MARK: - Scores

    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws {
        let currentUID = try requireUID()
        let filtered = scores.filter { score in
            let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
            return privacyService.shouldShare(score: score, game: game)
        }
        guard !filtered.isEmpty else { return }

        let allowedReaders = await currentAllowedReaders()

        let batch = db.batch()
        for score in filtered {
            let docId = "\(currentUID)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData(
                scoreDocData(userId: currentUID, score: score, allowedReaders: allowedReaders),
                forDocument: ref, merge: true
            )
        }
        do {
            try await batch.commit()
            pendingScores.removeAll()
            pendingScoreStore.save(pendingScores)
 logger.info("Published \(filtered.count) scores to Firebase")
        } catch {
            let socialError = FirebaseSocialError.from(error)
            // Always queue for retry — even "non-retryable" errors like permissionDenied
            // can be transient (e.g., App Check enforcement misconfiguration).
            pendingScores.append(contentsOf: filtered)
            pendingScoreStore.save(pendingScores)
 logger.warning("Queued \(filtered.count) scores for retry (error: \(error.localizedDescription))")
            throw socialError
        }
    }

    func flushPendingScoresIfNeeded() async {
        guard !pendingScores.isEmpty else { return }
        guard let currentUID = uid else {
 logger.debug("Skipping pending score flush — not authenticated")
            return
        }
        // Snapshot scores to flush but do NOT clear from Keychain yet —
        // if the app is killed before the batch commits, scores survive in Keychain.
        let toFlush = pendingScores

        let allowedReaders = await currentAllowedReaders()

        let batch = db.batch()
        for score in toFlush {
            let docId = "\(currentUID)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData(
                scoreDocData(userId: currentUID, score: score, allowedReaders: allowedReaders),
                forDocument: ref, merge: true
            )
        }
        do {
            try await batch.commit()
            // Clear from Keychain only AFTER successful commit
            pendingScores.removeAll()
            pendingScoreStore.save(pendingScores)
 logger.info("Flushed \(toFlush.count) pending scores")
        } catch {
            // Re-queue on failure (scores are still in pendingScores, just re-save)
            pendingScores.append(contentsOf: toFlush)
            pendingScoreStore.save(pendingScores)
 logger.warning("Re-queued \(toFlush.count) scores after flush failure: \(error.localizedDescription)")
        }
    }

    // MARK: - Score Reconciliation

    /// Republishes recent local results to the scores collection.
    /// Covers the last 7 days to catch scores dropped by previous publish failures,
    /// timezone bugs, or offline periods.
    /// Uses `setData(merge: true)` so already-published scores are harmlessly overwritten.
    func reconcileRecentScores(results: [GameResult], streaks: [GameStreak]) async {
        guard let currentUID = uid else { return }
        let cal = Calendar.current
        let cutoff = cal.startOfDay(for: cal.date(byAdding: .day, value: -7, to: Date()) ?? Date())
        let recentResults = results.filter { $0.date >= cutoff && $0.completed }
        guard !recentResults.isEmpty else { return }

        var scores: [DailyGameScore] = []
        for result in recentResults {
            let dateInt = result.date.localDateInt
            let streak = streaks.first(where: { $0.gameId == result.gameId })
            let compositeId = "\(currentUID)|\(dateInt)|\(result.gameId.uuidString)"
            scores.append(DailyGameScore(
                id: compositeId,
                userId: currentUID,
                dateInt: dateInt,
                gameId: result.gameId,
                gameName: result.gameName,
                score: result.score,
                maxAttempts: result.maxAttempts,
                completed: result.completed,
                currentStreak: streak?.currentStreak
            ))
        }

        let filtered = scores.filter { score in
            let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
            return privacyService.shouldShare(score: score, game: game)
        }
        guard !filtered.isEmpty else { return }

        let allowedReaders = await currentAllowedReaders()

        let batch = db.batch()
        for score in filtered {
            let docId = "\(currentUID)|\(score.dateInt)|\(score.gameId.uuidString)"
            let ref = db.collection("scores").document(docId)
            batch.setData(
                scoreDocData(userId: currentUID, score: score, allowedReaders: allowedReaders),
                forDocument: ref, merge: true
            )
        }
        do {
            try await batch.commit()
 logger.info("Reconciled \(filtered.count) scores from last 7 days")
        } catch {
 logger.warning("Score reconciliation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Allowed Readers Reconciliation

    /// Updates `allowedReaders` on the user's recent scores to reflect current friendships.
    /// Called after accept/remove friend to ensure new friends see past scores and
    /// removed friends lose access (privacy). Covers last 30 days.
    func reconcileAllowedReadersForFriendshipChange() async {
        guard let currentUID = uid else { return }
        let allowedReaders = await currentAllowedReaders()

        let cal = Calendar.current
        let cutoffDate = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let cutoffInt = cutoffDate.localDateInt

        do {
            let snapshot = try await db.collection("scores")
                .whereField("userId", isEqualTo: currentUID)
                .whereField("dateInt", isGreaterThanOrEqualTo: cutoffInt)
                .getDocuments()

            guard !snapshot.documents.isEmpty else { return }

            for chunk in snapshot.documents.chunked(into: 500) {
                let batch = db.batch()
                for doc in chunk {
                    batch.updateData(["allowedReaders": allowedReaders], forDocument: doc.reference)
                }
                try await batch.commit()
            }

 logger.info("Reconciled allowedReaders on \(snapshot.documents.count) scores after friendship change")
        } catch {
 logger.warning("Failed to reconcile allowedReaders: \(error.localizedDescription)")
        }
    }

}
