//
//  KeychainService.swift
//  StreakSync
//
//  Lightweight Keychain wrapper for storing sensitive data.
//  Uses kSecClassGenericPassword with the app's bundle ID as service.
//

import Foundation
import Security
import OSLog

struct KeychainService {

    private static let service = Bundle.main.bundleIdentifier ?? "com.mitsheth.StreakSync"
    private static let logger = Logger(subsystem: "com.streaksync.app", category: "Keychain")

    // MARK: - Data API

    static func save(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
 logger.warning("Keychain save failed for key '\(key)': \(status)")
        }
        return status == errSecSuccess
    }

    static func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
 logger.warning("Keychain load failed for key '\(key)': \(status)")
            }
            return nil
        }
        return result as? Data
    }

    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Codable Convenience

    static func saveCodable<T: Codable>(_ object: T, forKey key: String) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(object) else {
 logger.warning("Keychain encode failed for key '\(key)'")
            return false
        }
        return save(data, forKey: key)
    }

    static func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = load(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
}
