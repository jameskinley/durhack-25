import Foundation
import SwiftUI

struct JourneyRecord: Identifiable, Codable, Equatable {
    let id: String
    let startLocation: String
    let endLocation: String
    let date: Date
    let songCount: Int
    let duration: TimeInterval
}

enum RecentJourneysStore {
    private static let key = "recentJourneys"
    private static let maxEntries = 50

    static func loadAll() -> [JourneyRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            let decoded = try JSONDecoder().decode([JourneyRecord].self, from: data)
            return decoded
        } catch {
            print("Failed to decode recent journeys: \(error)")
            return []
        }
    }

    static func save(journey: JourneyRecord) {
        var current = loadAll()
        // Prepend new record
        current.insert(journey, at: 0)
        // Keep recent only
        if current.count > maxEntries {
            current = Array(current.prefix(maxEntries))
        }

        do {
            let encoded = try JSONEncoder().encode(current)
            UserDefaults.standard.set(encoded, forKey: key)
        } catch {
            print("Failed to encode recent journeys: \(error)")
        }
    }

    static func remove(at offsets: IndexSet) {
        var current = loadAll()
        current.remove(atOffsets: offsets)
        do {
            let encoded = try JSONEncoder().encode(current)
            UserDefaults.standard.set(encoded, forKey: key)
        } catch {
            print("Failed to update recent journeys: \(error)")
        }
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
