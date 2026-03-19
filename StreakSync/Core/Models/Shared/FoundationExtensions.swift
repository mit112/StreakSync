//
//  FoundationExtensions.swift
//  StreakSync
//
//  Date and URL convenience extensions.
//  Extracted from SharedModels.swift for maintainability.
//

import Foundation

// MARK: - Thread-Safe Date Extensions
extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    var daysSinceNow: Int {
        Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
    }
    
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
    
    var accessibilityDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}

// MARK: - URL Validation Extensions
extension URL {
    var isValidGameURL: Bool {
        guard let scheme = scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = host,
              !host.isEmpty else {
            return false
        }
        return true
    }

    var isSecure: Bool {
        scheme?.lowercased() == "https"
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
