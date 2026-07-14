import Foundation
import SwiftData

/// A movement in the exercise library. Built-in exercises can be edited or archived;
/// only custom exercises can be deleted.
@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    /// Raw muscle-group value; may be a built-in `MuscleGroup` raw value or a custom string.
    var primaryMuscleRaw: String = MuscleGroup.other.rawValue
    var secondaryMusclesRaw: [String] = []
    var categoryRaw: String = ExerciseCategory.strength.rawValue
    var equipmentRaw: String = EquipmentType.barbell.rawValue
    var movementPatternRaw: String = MovementPattern.other.rawValue
    var instructions: String = ""
    var personalNotes: String = ""
    var isUnilateral: Bool = false
    var usesWeight: Bool = true
    var usesReps: Bool = true
    var usesDuration: Bool = false
    var usesDistance: Bool = false
    var tracksRPE: Bool = true
    /// Suggested weight step in kilograms when adjusting load.
    var defaultIncrementKg: Double = 2.5
    var isFavorite: Bool = false
    var favoriteOrder: Int = 0
    var isArchived: Bool = false
    var isBuiltIn: Bool = false
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date()

    init(
        name: String,
        primaryMuscle: MuscleGroup = .other,
        secondaryMuscles: [MuscleGroup] = [],
        category: ExerciseCategory = .strength,
        equipment: EquipmentType = .barbell,
        movementPattern: MovementPattern = .other,
        instructions: String = "",
        isUnilateral: Bool = false,
        usesWeight: Bool = true,
        usesReps: Bool = true,
        usesDuration: Bool = false,
        usesDistance: Bool = false,
        tracksRPE: Bool = true,
        defaultIncrementKg: Double = 2.5,
        isBuiltIn: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMusclesRaw = secondaryMuscles.map(\.rawValue)
        self.categoryRaw = category.rawValue
        self.equipmentRaw = equipment.rawValue
        self.movementPatternRaw = movementPattern.rawValue
        self.instructions = instructions
        self.isUnilateral = isUnilateral
        self.usesWeight = usesWeight
        self.usesReps = usesReps
        self.usesDuration = usesDuration
        self.usesDistance = usesDistance
        self.tracksRPE = tracksRPE
        self.defaultIncrementKg = defaultIncrementKg
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
    }

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    var primaryMuscleDisplayName: String { MuscleGroup.displayName(for: primaryMuscleRaw) }
    var equipmentDisplayName: String { EquipmentType.displayName(for: equipmentRaw) }

    /// Deep copy used by the "duplicate" action.
    func duplicated() -> Exercise {
        let copy = Exercise(name: name + " Copy")
        copy.primaryMuscleRaw = primaryMuscleRaw
        copy.secondaryMusclesRaw = secondaryMusclesRaw
        copy.categoryRaw = categoryRaw
        copy.equipmentRaw = equipmentRaw
        copy.movementPatternRaw = movementPatternRaw
        copy.instructions = instructions
        copy.personalNotes = personalNotes
        copy.isUnilateral = isUnilateral
        copy.usesWeight = usesWeight
        copy.usesReps = usesReps
        copy.usesDuration = usesDuration
        copy.usesDistance = usesDistance
        copy.tracksRPE = tracksRPE
        copy.defaultIncrementKg = defaultIncrementKg
        copy.imageData = imageData
        copy.isBuiltIn = false
        return copy
    }
}
