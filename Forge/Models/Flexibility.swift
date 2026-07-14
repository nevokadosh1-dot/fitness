import Foundation
import SwiftData

/// A stretch or mobility drill in the flexibility library.
@Model
final class FlexibilityExercise {
    var id: UUID = UUID()
    var name: String = ""
    var instructions: String = ""
    /// Loose grouping such as "Hamstrings", "Hip Flexors", "Adductors".
    var targetArea: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var isBuiltIn: Bool = false
    var isArchived: Bool = false
    var createdAt: Date = Date()

    init(name: String, instructions: String = "", targetArea: String = "", isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.instructions = instructions
        self.targetArea = targetArea
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
    }
}

/// An ordered stretching routine (front split, middle split, mobility, …).
@Model
final class FlexibilityRoutine {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = FlexibilityKind.mobility.rawValue
    var details: String = ""
    var targetSessionsPerWeek: Int = 2
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \FlexibilityRoutineItem.routine)
    var items: [FlexibilityRoutineItem]? = []

    init(name: String, kind: FlexibilityKind, details: String = "", targetSessionsPerWeek: Int = 2) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.details = details
        self.targetSessionsPerWeek = targetSessionsPerWeek
        self.createdAt = Date()
    }

    var kind: FlexibilityKind {
        get { FlexibilityKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }

    var orderedItems: [FlexibilityRoutineItem] {
        (items ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Rough total duration including holds and rests, in seconds.
    var estimatedSeconds: Int {
        (items ?? []).reduce(0) { total, item in
            let sides = item.sideMode == .leftRight ? 2 : 1
            return total + item.sets * sides * (item.holdSeconds + item.restSeconds)
        }
    }
}

@Model
final class FlexibilityRoutineItem {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var exercise: FlexibilityExercise?
    var nameSnapshot: String = ""
    var instructionsSnapshot: String = ""
    var holdSeconds: Int = 45
    var sets: Int = 2
    var sideModeRaw: String = SideMode.bilateral.rawValue
    var restSeconds: Int = 15
    var notes: String = ""

    var routine: FlexibilityRoutine?

    init(exercise: FlexibilityExercise?, sortIndex: Int, holdSeconds: Int = 45, sets: Int = 2, sideMode: SideMode = .bilateral, restSeconds: Int = 15) {
        self.id = UUID()
        self.exercise = exercise
        self.nameSnapshot = exercise?.name ?? ""
        self.instructionsSnapshot = exercise?.instructions ?? ""
        self.sortIndex = sortIndex
        self.holdSeconds = holdSeconds
        self.sets = sets
        self.sideModeRaw = sideMode.rawValue
        self.restSeconds = restSeconds
    }

    var displayName: String { exercise?.name ?? nameSnapshot }
    var displayInstructions: String {
        let live = exercise?.instructions ?? ""
        return live.isEmpty ? instructionsSnapshot : live
    }

    var sideMode: SideMode {
        get { SideMode(rawValue: sideModeRaw) ?? .bilateral }
        set { sideModeRaw = newValue.rawValue }
    }
}

/// A completed (or in-progress) flexibility session.
@Model
final class FlexibilitySession {
    var id: UUID = UUID()
    var date: Date = Date()
    var routineID: UUID?
    var routineNameSnapshot: String = ""
    var kindRaw: String = FlexibilityKind.mobility.rawValue
    var durationSeconds: TimeInterval = 0
    /// 1–10 discomfort / intensity rating.
    var intensity: Int?
    var notes: String = ""
    var statusRaw: String = SessionStatus.completed.rawValue

    @Relationship(deleteRule: .cascade, inverse: \FlexibilityCompletedItem.session)
    var completedItems: [FlexibilityCompletedItem]? = []

    init(routine: FlexibilityRoutine?, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.routineID = routine?.id
        self.routineNameSnapshot = routine?.name ?? "Flexibility Session"
        self.kindRaw = routine?.kindRaw ?? FlexibilityKind.mobility.rawValue
    }

    var kind: FlexibilityKind {
        get { FlexibilityKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class FlexibilityCompletedItem {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var nameSnapshot: String = ""
    var setsCompleted: Int = 0
    var setsPlanned: Int = 0
    var holdSeconds: Int = 0
    var wasSkipped: Bool = false

    var session: FlexibilitySession?

    init(sortIndex: Int, name: String, setsPlanned: Int, holdSeconds: Int) {
        self.id = UUID()
        self.sortIndex = sortIndex
        self.nameSnapshot = name
        self.setsPlanned = setsPlanned
        self.holdSeconds = holdSeconds
    }
}

/// A manually entered flexibility progress measurement (per split, per method).
@Model
final class FlexibilityMeasurement {
    var id: UUID = UUID()
    var date: Date = Date()
    var targetRaw: String = SplitTarget.middle.rawValue
    var methodRaw: String = FlexibilityMetricMethod.floorDistance.rawValue
    /// Value in the method's canonical unit (cm, degrees, or 0–10 score).
    var value: Double = 0
    var notes: String = ""

    init(date: Date = Date(), target: SplitTarget, method: FlexibilityMetricMethod, value: Double, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.targetRaw = target.rawValue
        self.methodRaw = method.rawValue
        self.value = value
        self.notes = notes
    }

    var target: SplitTarget {
        get { SplitTarget(rawValue: targetRaw) ?? .middle }
        set { targetRaw = newValue.rawValue }
    }

    var method: FlexibilityMetricMethod {
        get { FlexibilityMetricMethod(rawValue: methodRaw) ?? .floorDistance }
        set { methodRaw = newValue.rawValue }
    }
}
