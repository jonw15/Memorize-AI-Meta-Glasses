/*
 * Quick Vision Storage Service
 * Quick image recognition history persistence service
 */

import Foundation

class QuickVisionStorage {
    static let shared = QuickVisionStorage()

    private let userDefaults = UserDefaults.standard
    private let recordsKey = "quickVisionRecords"
    private let maxRecords = 100 // Save up to 100 records

    private init() {}

    // MARK: - Save Record

    func saveRecord(_ record: QuickVisionRecord) {
        var records = loadAllRecords()

        // Add new record at the beginning
        records.insert(record, at: 0)

        // Keep only the most recent maxRecords
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }

        // Encode and save
        if let encoded = try? JSONEncoder().encode(records) {
            userDefaults.set(encoded, forKey: recordsKey)
            print("💾 [QuickVisionStorage] Record saved: \(record.id), total: \(records.count)")
        } else {
            print("❌ [QuickVisionStorage] Failed to save record")
        }
    }

    // MARK: - Load Records

    func loadAllRecords() -> [QuickVisionRecord] {
        guard let data = userDefaults.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([QuickVisionRecord].self, from: data) else {
            return []
        }
        return records
    }

    func loadRecords(limit: Int = 20, offset: Int = 0) -> [QuickVisionRecord] {
        let allRecords = loadAllRecords()
        let endIndex = min(offset + limit, allRecords.count)

        guard offset < allRecords.count else {
            return []
        }

        return Array(allRecords[offset..<endIndex])
    }

    // MARK: - Delete Records

    func deleteRecord(_ id: UUID) {
        var records = loadAllRecords()
        records.removeAll { $0.id == id }

        if let encoded = try? JSONEncoder().encode(records) {
            userDefaults.set(encoded, forKey: recordsKey)
            print("🗑️ [QuickVisionStorage] Record deleted: \(id)")
        }
    }

    func deleteAllRecords() {
        userDefaults.removeObject(forKey: recordsKey)
        print("🗑️ [QuickVisionStorage] All records cleared")
    }

    // MARK: - Get Record

    func getRecord(by id: UUID) -> QuickVisionRecord? {
        return loadAllRecords().first { $0.id == id }
    }

    // MARK: - Statistics

    var recordCount: Int {
        return loadAllRecords().count
    }
}
