//
//  MockPersistenceService.swift
//  StreakSync
//
//  In-memory PersistenceServiceProtocol for previews and tests
//

import Foundation

final class MockPersistenceService: PersistenceServiceProtocol {
    private var storage: [String: Data] = [:]
    
    func save<T: Codable>(_ object: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        storage[key] = try encoder.encode(object)
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = storage[key] else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }
    
    func remove(forKey key: String) {
        storage.removeValue(forKey: key)
    }
    
    func clearAll() {
        storage.removeAll()
    }
}
