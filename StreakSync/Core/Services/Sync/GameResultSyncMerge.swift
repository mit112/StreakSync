//
//  GameResultSyncMerge.swift
//  StreakSync
//
//  Pure, dependency-free merge/prune logic for GameResult cloud sync.
//  Extracted from FirestoreGameResultSyncService so the conflict-resolution,
//  push-selection, tombstone, and cap rules can be unit-tested against the
//  real shipping code instead of an inline copy.
//

import Foundation

enum GameResultSyncMerge {
    /// Merges local and remote results, resolving conflicts by `lastModified`
    /// (remote wins only when strictly newer). Ids present only remotely are appended.
    static func mergeResults(local: [GameResult], remote: [GameResult]) -> [GameResult] {
        var merged = local
        var indexById: [UUID: Int] = [:]
        for (i, result) in merged.enumerated() {
            indexById[result.id] = i
        }
        for remoteResult in remote {
            if let idx = indexById[remoteResult.id] {
                if remoteResult.lastModified > merged[idx].lastModified {
                    merged[idx] = remoteResult
                }
            } else {
                indexById[remoteResult.id] = merged.count
                merged.append(remoteResult)
            }
        }
        return merged
    }

    /// Selects the results that must be uploaded: local results that are either absent
    /// remotely or newer than their remote counterpart.
    static func resultsToPush(merged: [GameResult], local: [GameResult], remote: [GameResult]) -> [GameResult] {
        let localIDs = Set(local.map { $0.id })
        let remoteIDs = Set(remote.map { $0.id })
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { _, b in b })

        return merged.filter { item in
            guard localIDs.contains(item.id) else { return false }
            if !remoteIDs.contains(item.id) { return true }
            if let r = remoteByID[item.id], item.lastModified > r.lastModified {
                return true
            }
            return false
        }
    }

    /// Removes any results whose id is in the deletion tombstone set, so a deleted
    /// result can't be resurrected via merge, re-push, or full/cold resync.
    static func filterDeleted(_ results: [GameResult], deletedIds: Set<UUID>) -> [GameResult] {
        guard !deletedIds.isEmpty else { return results }
        return results.filter { !deletedIds.contains($0.id) }
    }

    /// Caps a result set to the newest `limit` by `date` (descending), breaking date
    /// ties deterministically by id so the kept set is stable regardless of input order.
    /// Returns the input unchanged when already within the cap (preserves caller ordering).
    static func pruneToCap(_ results: [GameResult], limit: Int) -> [GameResult] {
        guard results.count > limit else { return results }
        let sorted = results.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return Array(sorted.prefix(limit))
    }
}
