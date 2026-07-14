import Foundation

// Plain value types the analytics, PR and insights engines operate on.
// Keeping these independent of SwiftData makes every calculation unit-testable
// and lets a real AI backend be swapped in later without touching persistence.

struct SetSnapshot: Equatable {
    var setTypeRaw: String = SetType.working.rawValue
    var weightKg: Double?
    var reps: Int?
    var rpe: Double?
    var isCompleted: Bool = true

    var countsAsWorking: Bool {
        (SetType(rawValue: setTypeRaw) ?? .working).countsAsWorking
    }
}

struct ExercisePerformanceSnapshot: Equatable {
    var exerciseName: String
    var primaryMuscleRaw: String = MuscleGroup.other.rawValue
    var secondaryMusclesRaw: [String] = []
    var sets: [SetSnapshot] = []

    var volumeKg: Double { StrengthMath.totalVolumeKg(sets: sets) }
    var hardSets: Int { StrengthMath.hardSetCount(sets: sets) }
    var averageRPE: Double? { StrengthMath.averageRPE(sets: sets) }
    var bestE1RM: Double? { StrengthMath.bestEstimatedOneRM(sets: sets) }

    var topWeightKg: Double? {
        sets.filter { $0.isCompleted && $0.countsAsWorking }.compactMap(\.weightKg).max()
    }
}

struct SessionSnapshot: Equatable {
    var id: UUID
    var date: Date
    var name: String
    var durationSeconds: Double = 0
    var exercises: [ExercisePerformanceSnapshot] = []

    var totalVolumeKg: Double { exercises.reduce(0) { $0 + $1.volumeKg } }
    var hardSets: Int { exercises.reduce(0) { $0 + $1.hardSets } }

    var averageRPE: Double? {
        let all = exercises.flatMap(\.sets)
        return StrengthMath.averageRPE(sets: all)
    }
}

struct RunSnapshot: Equatable {
    var id: UUID
    var date: Date
    var distanceMeters: Double
    var durationSeconds: Double
    var runTypeRaw: String = RunType.easy.rawValue

    var paceSecondsPerKm: Double? {
        RunningMath.paceSecondsPerKm(distanceMeters: distanceMeters, durationSeconds: durationSeconds)
    }

    var matchedBenchmark: BenchmarkDistance? {
        BenchmarkDistance.allCases.first { abs(distanceMeters - $0.meters) <= $0.tolerance }
    }
}

struct FlexSessionSnapshot: Equatable {
    var id: UUID
    var date: Date
    var kindRaw: String
}

struct FlexMeasurementSnapshot: Equatable {
    var date: Date
    var targetRaw: String
    var methodRaw: String
    var value: Double
}

/// One week of schedule adherence, already resolved against overrides.
struct WeekAdherenceSnapshot: Equatable {
    var weekStart: Date
    var plannedCount: Int
    var completedCount: Int
    var skippedCount: Int

    /// Completion rate 0…1; a week with nothing planned counts as fully adhered.
    var completionRate: Double {
        guard plannedCount > 0 else { return 1 }
        return Double(completedCount) / Double(plannedCount)
    }
}
