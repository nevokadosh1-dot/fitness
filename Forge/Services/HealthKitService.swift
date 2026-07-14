import Foundation
import HealthKit
import SwiftData

/// Optional Apple Health integration. Read-only by default (running workouts
/// and body mass); writing strength workouts is a separate opt-in. The app is
/// fully functional when HealthKit is unavailable or denied.
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(distance) }
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(heartRate) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(energy) }
        if let mass = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(mass) }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    /// Requests read (and workout-write) permission. Returns false when
    /// unavailable or the request fails; denial is not an error state.
    func requestAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    // MARK: Import runs

    struct ImportedRun {
        var healthKitID: String
        var date: Date
        var distanceMeters: Double
        var durationSeconds: Double
        var averageHeartRate: Double?
        var calories: Double?
    }

    /// Fetches running workouts since `since` (defaults to 90 days back).
    func fetchRunningWorkouts(since: Date?) async -> [ImportedRun] {
        guard Self.isAvailable else { return [] }
        let start = since ?? Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let runPredicate = HKQuery.predicateForWorkouts(with: .running)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, runPredicate])

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 200,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        return workouts.map { workout in
            let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meter()) ?? 0
            let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            let heartRate = workout.statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            return ImportedRun(
                healthKitID: workout.uuid.uuidString,
                date: workout.startDate,
                distanceMeters: distance,
                durationSeconds: workout.duration,
                averageHeartRate: heartRate,
                calories: energy
            )
        }
    }

    /// Imports new running workouts, skipping any already imported (by HK UUID)
    /// and any manual run at the same time & distance. Returns the import count.
    @MainActor
    func importRuns(into context: ModelContext, settings: AppSettings) async -> Int {
        let imported = await fetchRunningWorkouts(since: settings.lastHealthKitImport)
        guard !imported.isEmpty else {
            settings.lastHealthKitImport = Date()
            try? context.save()
            return 0
        }
        let existing = StoreQueries.runs(in: context)
        let existingIDs = Set(existing.compactMap(\.healthKitID))

        var count = 0
        for run in imported {
            guard !existingIDs.contains(run.healthKitID) else { continue }
            // Avoid duplicating a manually logged version of the same run.
            let duplicate = existing.contains { manual in
                abs(manual.date.timeIntervalSince(run.date)) < 1800 &&
                abs(manual.distanceMeters - run.distanceMeters) < 200
            }
            guard !duplicate, run.distanceMeters > 0 else { continue }

            let session = RunningSession(date: run.date, runType: .easy,
                                         distanceMeters: run.distanceMeters,
                                         durationSeconds: run.durationSeconds)
            session.averageHeartRate = run.averageHeartRate
            session.calories = run.calories
            session.source = "healthkit"
            session.healthKitID = run.healthKitID
            context.insert(session)
            count += 1
        }
        settings.lastHealthKitImport = Date()
        try? context.save()
        if count > 0 { PRService.recompute(in: context) }
        return count
    }

    // MARK: Import body mass

    @MainActor
    func importBodyMass(into context: ModelContext) async -> Int {
        guard Self.isAvailable, let massType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return 0 }
        let start = Calendar.current.date(byAdding: .day, value: -180, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: massType, predicate: predicate, limit: 500,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        let metricRaw = BodyMetric.bodyWeight.rawValue
        let existing = StoreQueries.bodyEntries(in: context, metricRaw: metricRaw)
        let existingIDs = Set(existing.compactMap(\.healthKitID))
        let calendar = Calendar.current

        var count = 0
        for sample in samples {
            let id = sample.uuid.uuidString
            guard !existingIDs.contains(id) else { continue }
            // One imported weight per day; skip days that already have a manual entry.
            let hasSameDay = existing.contains { calendar.isDate($0.date, inSameDayAs: sample.startDate) }
            guard !hasSameDay else { continue }

            let entry = BodyMeasurementEntry(
                date: sample.startDate,
                metricRaw: metricRaw,
                value: sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            )
            entry.source = "healthkit"
            entry.healthKitID = id
            context.insert(entry)
            count += 1
        }
        try? context.save()
        return count
    }

    // MARK: Write strength workouts (opt-in)

    /// Saves a completed strength session to Health as a traditional
    /// strength-training workout. Fails silently if permission was denied.
    func saveStrengthWorkout(_ session: WorkoutSession) async {
        guard Self.isAvailable,
              let completedAt = session.completedAt,
              session.duration > 60 else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            let start = completedAt.addingTimeInterval(-session.duration)
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: completedAt)
            _ = try await builder.finishWorkout()
        } catch {
            // Denied or restricted — nothing to do; manual logs remain the source of truth.
        }
    }
}
