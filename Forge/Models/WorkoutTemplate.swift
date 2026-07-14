import Foundation
import SwiftData

/// A reusable strength-workout plan. Editing a template never changes past sessions,
/// because sessions snapshot everything they need at start time.
@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var details: String = ""
    var notes: String = ""
    /// Hex color string used for the template accent, e.g. "#4AC766".
    var colorHex: String = "#4AC766"
    var iconName: String = "dumbbell.fill"
    var estimatedMinutes: Int?
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]? = []

    init(name: String, details: String = "", colorHex: String = "#4AC766", iconName: String = "dumbbell.fill") {
        self.id = UUID()
        self.name = name
        self.details = details
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var orderedExercises: [TemplateExercise] {
        (exercises ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var exerciseCount: Int { exercises?.count ?? 0 }

    var totalPlannedSets: Int {
        (exercises ?? []).reduce(0) { $0 + ($1.plannedSets?.count ?? 0) }
    }
}

@Model
final class TemplateExercise {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    /// Reference into the library; kept nullable so deleting a library exercise
    /// never breaks a template (the snapshot name remains).
    var exercise: Exercise?
    var exerciseNameSnapshot: String = ""
    var notes: String = ""
    /// Exercises sharing a non-nil group number form a superset / circuit.
    var supersetGroup: Int?
    /// Library IDs of acceptable substitute exercises.
    var alternativeExerciseIDs: [UUID] = []

    var template: WorkoutTemplate?

    @Relationship(deleteRule: .cascade, inverse: \PlannedSet.templateExercise)
    var plannedSets: [PlannedSet]? = []

    init(exercise: Exercise?, sortIndex: Int) {
        self.id = UUID()
        self.exercise = exercise
        self.exerciseNameSnapshot = exercise?.name ?? ""
        self.sortIndex = sortIndex
    }

    var displayName: String { exercise?.name ?? exerciseNameSnapshot }

    var orderedPlannedSets: [PlannedSet] {
        (plannedSets ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }
}

@Model
final class PlannedSet {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var setTypeRaw: String = SetType.working.rawValue
    var targetRepsMin: Int?
    var targetRepsMax: Int?
    /// Target load in kilograms.
    var targetWeightKg: Double?
    var targetRPE: Double?

    var templateExercise: TemplateExercise?

    init(sortIndex: Int, setType: SetType = .working) {
        self.id = UUID()
        self.sortIndex = sortIndex
        self.setTypeRaw = setType.rawValue
    }

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }

    var repRangeText: String {
        switch (targetRepsMin, targetRepsMax) {
        case let (min?, max?) where min != max: return "\(min)–\(max)"
        case let (min?, _): return "\(min)"
        case let (nil, max?): return "\(max)"
        default: return "—"
        }
    }
}
