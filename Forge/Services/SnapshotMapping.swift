import Foundation
import SwiftData

// Converts live SwiftData models into the plain snapshot types used by the
// Core analytics, PR-detection and insights engines.

extension WorkoutSession {
    var snapshot: SessionSnapshot {
        SessionSnapshot(
            id: id,
            date: completedAt ?? startedAt,
            name: name,
            durationSeconds: duration,
            exercises: orderedExercises.map(\.performanceSnapshot)
        )
    }
}

extension WorkoutExercise {
    var performanceSnapshot: ExercisePerformanceSnapshot {
        ExercisePerformanceSnapshot(
            exerciseName: displayName,
            primaryMuscleRaw: primaryMuscleSnapshot,
            secondaryMusclesRaw: secondaryMusclesSnapshot,
            sets: orderedSets.map { set in
                SetSnapshot(
                    setTypeRaw: set.setTypeRaw,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    rpe: set.rpe,
                    isCompleted: set.isCompleted
                )
            }
        )
    }
}

extension RunningSession {
    var snapshot: RunSnapshot {
        RunSnapshot(
            id: id,
            date: date,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            runTypeRaw: runTypeRaw
        )
    }
}

extension FlexibilitySession {
    var snapshot: FlexSessionSnapshot {
        FlexSessionSnapshot(id: id, date: date, kindRaw: kindRaw)
    }
}

extension FlexibilityMeasurement {
    var snapshot: FlexMeasurementSnapshot {
        FlexMeasurementSnapshot(date: date, targetRaw: targetRaw, methodRaw: methodRaw, value: value)
    }
}

/// Convenience fetches used by the analytics/insights layers.
enum StoreQueries {

    static func completedSessions(in context: ModelContext, since: Date? = nil) -> [WorkoutSession] {
        let completedRaw = SessionStatus.completed.rawValue
        var descriptor: FetchDescriptor<WorkoutSession>
        if let since {
            descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.statusRaw == completedRaw && $0.startedAt >= since },
                sortBy: [SortDescriptor(\.startedAt)]
            )
        } else {
            descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.statusRaw == completedRaw },
                sortBy: [SortDescriptor(\.startedAt)]
            )
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func runs(in context: ModelContext, since: Date? = nil) -> [RunningSession] {
        var descriptor: FetchDescriptor<RunningSession>
        if let since {
            descriptor = FetchDescriptor<RunningSession>(
                predicate: #Predicate { $0.date >= since },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<RunningSession>(sortBy: [SortDescriptor(\.date)])
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func flexSessions(in context: ModelContext, since: Date? = nil) -> [FlexibilitySession] {
        var descriptor: FetchDescriptor<FlexibilitySession>
        if let since {
            descriptor = FetchDescriptor<FlexibilitySession>(
                predicate: #Predicate { $0.date >= since },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<FlexibilitySession>(sortBy: [SortDescriptor(\.date)])
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func flexMeasurements(in context: ModelContext) -> [FlexibilityMeasurement] {
        let descriptor = FetchDescriptor<FlexibilityMeasurement>(sortBy: [SortDescriptor(\.date)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func bodyEntries(in context: ModelContext, metricRaw: String, since: Date? = nil) -> [BodyMeasurementEntry] {
        var descriptor: FetchDescriptor<BodyMeasurementEntry>
        if let since {
            descriptor = FetchDescriptor<BodyMeasurementEntry>(
                predicate: #Predicate { $0.metricRaw == metricRaw && $0.date >= since },
                sortBy: [SortDescriptor(\.date)]
            )
        } else {
            descriptor = FetchDescriptor<BodyMeasurementEntry>(
                predicate: #Predicate { $0.metricRaw == metricRaw },
                sortBy: [SortDescriptor(\.date)]
            )
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The workout session currently in progress, if any.
    static func activeSession(in context: ModelContext) -> WorkoutSession? {
        let activeRaw = SessionStatus.active.rawValue
        let pausedRaw = SessionStatus.paused.rawValue
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == activeRaw || $0.statusRaw == pausedRaw },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).first
    }
}
