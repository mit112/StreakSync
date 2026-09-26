//
//  FoundationExtensions.swift
//  StreakSync
//
//  Date, collection and string convenience extensions.
//  Extracted from SharedModels.swift for maintainability.
//

import Foundation

// MARK: - Date Extensions
extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}

// MARK: - Array Chunking

extension Array {
    /// Splits the array into sub-arrays of at most `size` elements.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var result: [[Element]] = []
        var chunk: [Element] = []
        chunk.reserveCapacity(size)
        for element in self {
            chunk.append(element)
            if chunk.count == size {
                result.append(chunk)
                chunk.removeAll(keepingCapacity: true)
            }
        }
        if !chunk.isEmpty { result.append(chunk) }
        return result
    }
}

// MARK: - String Helpers

extension String {
    /// Returns `nil` when the string is empty, otherwise returns `self`.
    var nonEmpty: String? { isEmpty ? nil : self }
}
