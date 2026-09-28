//
//  SyncServerWatermark.swift
//  StreakSync
//
//  Advancing the server-clock watermark behind the serverModified sync query
//

import Foundation

enum SyncServerWatermark {
    /// Page size for the `serverModified >= watermark` query. It must exceed the largest
    /// group of documents that can share one timestamp — a WriteBatch (500 writes) commits
    /// at a single server time — so a full page always spans two timestamps and advances.
    static let pageLimit = 1000

    /// The watermark after a page of `serverModified >= current` results, ascending. The
    /// query is inclusive, so documents at the returned time are read again next sync
    /// rather than skipped when a page boundary splits a same-timestamp batch.
    static func advanced(from current: Date?, fetched: [Date]) -> Date? {
        guard let newest = fetched.max() else { return current }
        guard let current else { return newest }
        return max(current, newest)
    }
}
