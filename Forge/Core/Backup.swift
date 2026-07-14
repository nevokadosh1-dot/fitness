import Foundation

// MARK: - Backup document (versioned JSON)

/// Codable mirror of the entire store. Kept independent of SwiftData so backups
/// remain decodable even if the live schema evolves (with migration shims here).
struct BackupDocument: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = BackupDocument.currentSchemaVersion
    var exportedAt: Date = Date()
    var exercises: [ExerciseDTO] = []
    var templates: [TemplateDTO] = []
    var sessions: [SessionDTO] = []
    var runs: [RunDTO] = []
    var flexibilityExercises: [FlexExerciseDTO] = []
    var flexibilityRoutines: [FlexRoutineDTO] = []
    var flexibilitySessions: [FlexSessionDTO] = []
    var flexibilityMeasurements: [FlexMeasurementDTO] = []
    var schedules: [ScheduleDTO] = []
    var scheduleOverrides: [ScheduleOverrideDTO] = []
    var bodyEntries: [BodyEntryDTO] = []
    /// Photos are exported without pixels by default (metadata only) to keep
    /// backups small; a full export including images is available separately.
    var photos: [PhotoDTO] = []
    var settings: SettingsDTO?
}

struct ExerciseDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var primaryMuscleRaw: String
    var secondaryMusclesRaw: [String]
    var categoryRaw: String
    var equipmentRaw: String
    var movementPatternRaw: String
    var instructions: String
    var personalNotes: String
    var isUnilateral: Bool
    var usesWeight: Bool
    var usesReps: Bool
    var usesDuration: Bool
    var usesDistance: Bool
    var tracksRPE: Bool
    var defaultIncrementKg: Double
    var isFavorite: Bool
    var favoriteOrder: Int
    var isArchived: Bool
    var isBuiltIn: Bool
    var createdAt: Date
}

struct PlannedSetDTO: Codable {
    var sortIndex: Int
    var setTypeRaw: String
    var targetRepsMin: Int?
    var targetRepsMax: Int?
    var targetWeightKg: Double?
    var targetRPE: Double?
}

struct TemplateExerciseDTO: Codable {
    var sortIndex: Int
    var exerciseID: UUID?
    var exerciseNameSnapshot: String
    var notes: String
    var supersetGroup: Int?
    var alternativeExerciseIDs: [UUID]
    var plannedSets: [PlannedSetDTO]
}

struct TemplateDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var details: String
    var notes: String
    var colorHex: String
    var iconName: String
    var estimatedMinutes: Int?
    var isArchived: Bool
    var createdAt: Date
    var exercises: [TemplateExerciseDTO]
}

struct CompletedSetDTO: Codable {
    var sortIndex: Int
    var setTypeRaw: String
    var weightKg: Double?
    var reps: Int?
    var rpe: Double?
    var durationSeconds: Double?
    var distanceMeters: Double?
    var isCompleted: Bool
    var notes: String
    var completedAt: Date?
}

struct WorkoutExerciseDTO: Codable {
    var sortIndex: Int
    var exerciseID: UUID?
    var nameSnapshot: String
    var primaryMuscleSnapshot: String
    var secondaryMusclesSnapshot: [String]
    var usesWeight: Bool
    var usesReps: Bool
    var tracksRPE: Bool
    var isUnilateral: Bool
    var notes: String
    var supersetGroup: Int?
    var sets: [CompletedSetDTO]
}

struct SessionDTO: Codable, Identifiable {
    var id: UUID
    var statusRaw: String
    var name: String
    var startedAt: Date
    var completedAt: Date?
    var pausedSeconds: Double
    var templateID: UUID?
    var templateNameSnapshot: String
    var notes: String
    var rating: Int?
    var energy: Int?
    var soreness: Int?
    var readiness: Int?
    var exercises: [WorkoutExerciseDTO]
}

struct RunSplitDTO: Codable {
    var sortIndex: Int
    var distanceMeters: Double
    var durationSeconds: Double
}

struct RunDTO: Codable, Identifiable {
    var id: UUID
    var date: Date
    var runTypeRaw: String
    var distanceMeters: Double
    var durationSeconds: Double
    var surfaceRaw: String
    var routeTypeRaw: String
    var rpe: Double?
    var averageHeartRate: Double?
    var calories: Double?
    var notes: String
    var intervalStructure: String
    var source: String
    var healthKitID: String?
    var splits: [RunSplitDTO]
}

struct FlexExerciseDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var instructions: String
    var targetArea: String
    var isBuiltIn: Bool
    var isArchived: Bool
    var createdAt: Date
}

struct FlexRoutineItemDTO: Codable {
    var sortIndex: Int
    var exerciseID: UUID?
    var nameSnapshot: String
    var instructionsSnapshot: String
    var holdSeconds: Int
    var sets: Int
    var sideModeRaw: String
    var restSeconds: Int
    var notes: String
}

struct FlexRoutineDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var kindRaw: String
    var details: String
    var targetSessionsPerWeek: Int
    var isArchived: Bool
    var createdAt: Date
    var items: [FlexRoutineItemDTO]
}

struct FlexCompletedItemDTO: Codable {
    var sortIndex: Int
    var nameSnapshot: String
    var setsCompleted: Int
    var setsPlanned: Int
    var holdSeconds: Int
    var wasSkipped: Bool
}

struct FlexSessionDTO: Codable, Identifiable {
    var id: UUID
    var date: Date
    var routineID: UUID?
    var routineNameSnapshot: String
    var kindRaw: String
    var durationSeconds: Double
    var intensity: Int?
    var notes: String
    var statusRaw: String
    var completedItems: [FlexCompletedItemDTO]
}

struct FlexMeasurementDTO: Codable, Identifiable {
    var id: UUID
    var date: Date
    var targetRaw: String
    var methodRaw: String
    var value: Double
    var notes: String
}

struct ScheduledActivityDTO: Codable, Identifiable {
    var id: UUID
    var weekday: Int
    var sortIndex: Int
    var kindRaw: String
    var title: String
    var templateID: UUID?
    var routineID: UUID?
    var notes: String
}

struct ScheduleDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var isActive: Bool
    var createdAt: Date
    var activities: [ScheduledActivityDTO]
}

struct ScheduleOverrideDTO: Codable, Identifiable {
    var id: UUID
    var weekStart: Date
    var activityID: UUID?
    var statusRaw: String
    var movedToWeekday: Int?
    var kindRaw: String?
    var title: String?
    var templateID: UUID?
    var routineID: UUID?
    var completedSessionID: UUID?
    var completedAt: Date?
}

struct BodyEntryDTO: Codable, Identifiable {
    var id: UUID
    var date: Date
    var metricRaw: String
    var value: Double
    var notes: String
    var source: String
    var healthKitID: String?
}

struct PhotoDTO: Codable, Identifiable {
    var id: UUID
    var date: Date
    var angleRaw: String
    var customAngleLabel: String
    var bodyWeightKg: Double?
    var notes: String
    var tags: [String]
    /// Base64 JPEG; present only in full exports.
    var imageBase64: String?
}

struct SettingsDTO: Codable {
    var weightUnitRaw: String
    var distanceUnitRaw: String
    var lengthUnitRaw: String
    var defaultIncrementKg: Double
    var showRPE: Bool
    var firstWeekday: Int
    var dashboardCardsRaw: [String]
    var disabledInsightCategories: [String]
    var runningGoalLabel: String
    var runningGoalDistanceMeters: Double
    var runningGoalSeconds: Double
    var customMuscleGroups: [String]
    var customEquipment: [String]
    var customRunTypes: [String]
    var customStretchAreas: [String]
    var customBodyMetrics: [String]
    var customActivityKinds: [String]
}

// MARK: - Validation

enum BackupValidationError: Error, Equatable, CustomStringConvertible {
    case unreadableFile
    case invalidJSON(String)
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case corruptData(String)

    var description: String {
        switch self {
        case .unreadableFile:
            return "The file could not be read."
        case .invalidJSON(let detail):
            return "The file is not a valid Forge backup: \(detail)"
        case .unsupportedSchemaVersion(let found, let supported):
            return "This backup uses schema version \(found); this app supports up to \(supported). Update the app to restore it."
        case .corruptData(let detail):
            return "The backup contains invalid data: \(detail)"
        }
    }
}

struct BackupValidationSummary: Equatable {
    var exerciseCount = 0
    var templateCount = 0
    var sessionCount = 0
    var runCount = 0
    var flexRoutineCount = 0
    var flexSessionCount = 0
    var measurementCount = 0
    var bodyEntryCount = 0
    var scheduleCount = 0
    var photoCount = 0
    var warnings: [String] = []
}

enum BackupValidator {

    static func decode(_ data: Data) -> Result<BackupDocument, BackupValidationError> {
        guard !data.isEmpty else { return .failure(.unreadableFile) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let document = try decoder.decode(BackupDocument.self, from: data)
            guard document.schemaVersion <= BackupDocument.currentSchemaVersion else {
                return .failure(.unsupportedSchemaVersion(
                    found: document.schemaVersion,
                    supported: BackupDocument.currentSchemaVersion
                ))
            }
            return .success(document)
        } catch let error as DecodingError {
            return .failure(.invalidJSON(shortDescription(of: error)))
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }
    }

    /// Semantic checks after decoding. Returns counts plus non-fatal warnings.
    static func validate(_ document: BackupDocument) -> Result<BackupValidationSummary, BackupValidationError> {
        var summary = BackupValidationSummary()

        var seenIDs = Set<UUID>()
        for exercise in document.exercises {
            guard !exercise.name.trimmingCharacters(in: .whitespaces).isEmpty else {
                return .failure(.corruptData("an exercise has an empty name"))
            }
            if !seenIDs.insert(exercise.id).inserted {
                return .failure(.corruptData("duplicate exercise ID \(exercise.id)"))
            }
        }
        summary.exerciseCount = document.exercises.count

        var sessionIDs = Set<UUID>()
        for session in document.sessions {
            if !sessionIDs.insert(session.id).inserted {
                return .failure(.corruptData("duplicate session ID \(session.id)"))
            }
            for exercise in session.exercises {
                for set in exercise.sets {
                    if let weight = set.weightKg, !weight.isFinite || weight < 0 {
                        return .failure(.corruptData("a set in '\(session.name)' has an invalid weight"))
                    }
                    if let reps = set.reps, reps < 0 || reps > 10_000 {
                        return .failure(.corruptData("a set in '\(session.name)' has an invalid rep count"))
                    }
                    if let rpe = set.rpe, !(0...10).contains(rpe) {
                        return .failure(.corruptData("a set in '\(session.name)' has an RPE outside 0–10"))
                    }
                }
            }
            if let completed = session.completedAt, completed < session.startedAt {
                summary.warnings.append("Session '\(session.name)' ends before it starts; dates will be kept as-is.")
            }
        }
        summary.sessionCount = document.sessions.count

        var runIDs = Set<UUID>()
        for run in document.runs {
            if !runIDs.insert(run.id).inserted {
                return .failure(.corruptData("duplicate run ID \(run.id)"))
            }
            guard run.distanceMeters.isFinite, run.distanceMeters >= 0,
                  run.durationSeconds.isFinite, run.durationSeconds >= 0 else {
                return .failure(.corruptData("a run has an invalid distance or duration"))
            }
        }
        summary.runCount = document.runs.count

        for measurement in document.flexibilityMeasurements where !measurement.value.isFinite {
            return .failure(.corruptData("a flexibility measurement has an invalid value"))
        }
        for entry in document.bodyEntries where !entry.value.isFinite || entry.value < 0 {
            return .failure(.corruptData("a body measurement has an invalid value"))
        }

        summary.templateCount = document.templates.count
        summary.flexRoutineCount = document.flexibilityRoutines.count
        summary.flexSessionCount = document.flexibilitySessions.count
        summary.measurementCount = document.flexibilityMeasurements.count
        summary.bodyEntryCount = document.bodyEntries.count
        summary.scheduleCount = document.schedules.count
        summary.photoCount = document.photos.count

        let activeSchedules = document.schedules.filter(\.isActive).count
        if activeSchedules > 1 {
            summary.warnings.append("Backup marks \(activeSchedules) schedules active; only the first will stay active.")
        }
        return .success(summary)
    }

    static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    private static func shortDescription(of error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _): return "missing field '\(key.stringValue)'"
        case .typeMismatch(_, let context): return "wrong type at '\(context.codingPath.map(\.stringValue).joined(separator: "."))'"
        case .valueNotFound(_, let context): return "missing value at '\(context.codingPath.map(\.stringValue).joined(separator: "."))'"
        case .dataCorrupted(let context): return context.debugDescription
        @unknown default: return "unknown decoding problem"
        }
    }
}

// MARK: - CSV export

enum CSVExporter {

    /// One row per set: date, workout, exercise, set number, type, weight, reps, RPE.
    static func workoutsCSV(sessions: [SessionDTO]) -> String {
        var rows = ["date,workout,exercise,set_index,set_type,weight_kg,reps,rpe,completed,notes"]
        let dateFormatter = ISO8601DateFormatter()
        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            for exercise in session.exercises.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                for set in exercise.sets.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                    rows.append([
                        dateFormatter.string(from: session.startedAt),
                        escape(session.name),
                        escape(exercise.nameSnapshot),
                        String(set.sortIndex + 1),
                        set.setTypeRaw,
                        set.weightKg.map { Formatting.trimmed($0) } ?? "",
                        set.reps.map(String.init) ?? "",
                        set.rpe.map { Formatting.trimmed($0, maxDecimals: 1) } ?? "",
                        set.isCompleted ? "yes" : "no",
                        escape(set.notes),
                    ].joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    static func runsCSV(runs: [RunDTO]) -> String {
        var rows = ["date,type,distance_m,duration_s,pace_s_per_km,surface,route,rpe,avg_hr,calories,notes"]
        let dateFormatter = ISO8601DateFormatter()
        for run in runs.sorted(by: { $0.date < $1.date }) {
            let pace = RunningMath.paceSecondsPerKm(distanceMeters: run.distanceMeters, durationSeconds: run.durationSeconds)
            rows.append([
                dateFormatter.string(from: run.date),
                run.runTypeRaw,
                Formatting.trimmed(run.distanceMeters),
                Formatting.trimmed(run.durationSeconds),
                pace.map { Formatting.trimmed($0, maxDecimals: 1) } ?? "",
                run.surfaceRaw,
                run.routeTypeRaw,
                run.rpe.map { Formatting.trimmed($0, maxDecimals: 1) } ?? "",
                run.averageHeartRate.map { Formatting.trimmed($0, maxDecimals: 0) } ?? "",
                run.calories.map { Formatting.trimmed($0, maxDecimals: 0) } ?? "",
                escape(run.notes),
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    static func measurementsCSV(entries: [BodyEntryDTO]) -> String {
        var rows = ["date,metric,value,notes"]
        let dateFormatter = ISO8601DateFormatter()
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            rows.append([
                dateFormatter.string(from: entry.date),
                escape(entry.metricRaw),
                Formatting.trimmed(entry.value),
                escape(entry.notes),
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    /// RFC-4180 style escaping for fields containing commas, quotes or newlines.
    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
