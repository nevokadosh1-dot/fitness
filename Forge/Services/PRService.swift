import Foundation
import SwiftData

/// Owns the cached `PersonalRecord` rows. Records are recomputed from raw
/// history whenever sessions change, so editing or deleting old sessions
/// always produces correct records.
enum PRService {

    @discardableResult
    static func recompute(in context: ModelContext) -> [PersonalRecord] {
        let sessions = StoreQueries.completedSessions(in: context).map(\.snapshot)
        let runs = StoreQueries.runs(in: context).map(\.snapshot)
        let measurements = StoreQueries.flexMeasurements(in: context).map(\.snapshot)
        let flexSessions = StoreQueries.flexSessions(in: context).map(\.snapshot)

        let detected = PRDetector.allRecords(
            sessions: sessions,
            runs: runs,
            measurements: measurements,
            flexSessions: flexSessions
        )

        // Replace the cache wholesale; it is derived data.
        let existing = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        for record in existing { context.delete(record) }

        let models = detected.map { detected in
            PersonalRecord(
                kind: detected.kind,
                subject: detected.subject,
                detail: detected.detail,
                value: detected.value,
                date: detected.date,
                sessionID: detected.sessionID
            )
        }
        for model in models { context.insert(model) }
        try? context.save()
        return models
    }

    /// Records achieved within the last `days` days, newest first.
    static func recent(in context: ModelContext, days: Int = 30) -> [PersonalRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
