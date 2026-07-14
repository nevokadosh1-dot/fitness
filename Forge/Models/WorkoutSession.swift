import Foundation
import SwiftData

/// A logged (or in-progress) strength workout. Autosaved continuously through SwiftData,
/// so an interrupted session can always be recovered on next launch.
@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var statusRaw: String = SessionStatus.active.rawValue
    var name: String = ""
    var startedAt: Date = Date()
    var completedAt: Date?
    /// Seconds spent paused, excluded from the displayed duration.
    var pausedSeconds: TimeInterval = 0
    var pauseStartedAt: Date?
    /// Source template, if any. Stored by ID + name snapshot so template edits
    /// and deletions never alter history.
    var templateID: UUID?
    var templateNameSnapshot: String = ""
    var notes: String = ""
    /// 1–5 session rating.
    var rating: Int?
    /// 1–10 subjective scores captured at finish.
    var energy: Int?
    var soreness: Int?
    var readiness: Int?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session)
    var exercises: [WorkoutExercise]? = []

    init(name: String, template: WorkoutTemplate? = nil) {
        self.id = UUID()
        self.name = name
        self.startedAt = Date()
        self.templateID = template?.id
        self.templateNameSnapshot = template?.name ?? ""
        self.statusRaw = SessionStatus.active.rawValue
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    var orderedExercises: [WorkoutExercise] {
        (exercises ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Active duration in seconds, excluding paused time.
    var duration: TimeInterval {
        let end = completedAt ?? Date()
        var paused = pausedSeconds
        if let pauseStart = pauseStartedAt, completedAt == nil {
            paused += end.timeIntervalSince(pauseStart)
        }
        return max(0, end.timeIntervalSince(startedAt) - paused)
    }

    /// Total volume in kg (weight × reps over completed working-type sets).
    var totalVolumeKg: Double {
        (exercises ?? []).reduce(0) { $0 + $1.volumeKg }
    }

    var completedSetCount: Int {
        (exercises ?? []).reduce(0) { total, exercise in
            total + (exercise.sets ?? []).filter(\.isCompleted).count
        }
    }

    var hardSetCount: Int {
        (exercises ?? []).reduce(0) { total, exercise in
            total + (exercise.sets ?? []).filter { $0.isCompleted && $0.setType.countsAsWorking }.count
        }
    }

    var averageRPE: Double? {
        let rpes = (exercises ?? [])
            .flatMap { $0.sets ?? [] }
            .filter { $0.isCompleted && $0.setType.countsAsWorking }
            .compactMap(\.rpe)
        guard !rpes.isEmpty else { return nil }
        return rpes.reduce(0, +) / Double(rpes.count)
    }
}

/// One exercise performed within a session. Snapshots the library exercise's
/// name and tracking flags so history stays accurate if the library changes.
@Model
final class WorkoutExercise {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var exercise: Exercise?
    var nameSnapshot: String = ""
    var primaryMuscleSnapshot: String = MuscleGroup.other.rawValue
    var secondaryMusclesSnapshot: [String] = []
    var usesWeight: Bool = true
    var usesReps: Bool = true
    var usesDuration: Bool = false
    var tracksRPE: Bool = true
    var incrementKg: Double = 2.5
    var isUnilateral: Bool = false
    var notes: String = ""
    var supersetGroup: Int?

    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \CompletedSet.workoutExercise)
    var sets: [CompletedSet]? = []

    init(exercise: Exercise?, sortIndex: Int) {
        self.id = UUID()
        self.sortIndex = sortIndex
        self.exercise = exercise
        if let exercise {
            self.nameSnapshot = exercise.name
            self.primaryMuscleSnapshot = exercise.primaryMuscleRaw
            self.secondaryMusclesSnapshot = exercise.secondaryMusclesRaw
            self.usesWeight = exercise.usesWeight
            self.usesReps = exercise.usesReps
            self.usesDuration = exercise.usesDuration
            self.tracksRPE = exercise.tracksRPE
            self.incrementKg = exercise.defaultIncrementKg
            self.isUnilateral = exercise.isUnilateral
        }
    }

    var displayName: String { nameSnapshot.isEmpty ? (exercise?.name ?? "Exercise") : nameSnapshot }

    var orderedSets: [CompletedSet] {
        (sets ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var volumeKg: Double {
        (sets ?? [])
            .filter { $0.isCompleted && $0.setType.countsAsWorking }
            .reduce(0) { $0 + (($1.weightKg ?? 0) * Double($1.reps ?? 0)) }
    }

    /// Best estimated 1RM among completed working sets, if computable.
    var bestEstimatedOneRM: Double? {
        (sets ?? [])
            .filter { $0.isCompleted && $0.setType.countsAsWorking }
            .compactMap { set -> Double? in
                guard let weight = set.weightKg, let reps = set.reps else { return nil }
                return StrengthMath.estimatedOneRM(weightKg: weight, reps: reps)
            }
            .max()
    }
}

@Model
final class CompletedSet {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var setTypeRaw: String = SetType.working.rawValue
    var weightKg: Double?
    var reps: Int?
    var rpe: Double?
    var durationSeconds: TimeInterval?
    var distanceMeters: Double?
    var isCompleted: Bool = false
    var notes: String = ""
    var completedAt: Date?
    // Planned targets snapshotted from the template at session start,
    // shown during the live workout. Template edits never touch these.
    var targetRepsMin: Int?
    var targetRepsMax: Int?
    var targetWeightKg: Double?
    var targetRPE: Double?

    var workoutExercise: WorkoutExercise?

    init(sortIndex: Int, setType: SetType = .working) {
        self.id = UUID()
        self.sortIndex = sortIndex
        self.setTypeRaw = setType.rawValue
    }

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }

    var targetText: String? {
        var parts: [String] = []
        if let weight = targetWeightKg { parts.append("\(Formatting.trimmed(weight)) kg") }
        switch (targetRepsMin, targetRepsMax) {
        case let (min?, max?) where min != max: parts.append("\(min)–\(max) reps")
        case let (min?, _): parts.append("\(min) reps")
        case let (nil, max?): parts.append("\(max) reps")
        default: break
        }
        if let rpe = targetRPE { parts.append("@\(Formatting.trimmed(rpe, maxDecimals: 1))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
