import XCTest
@testable import Forge

final class BackupTests: XCTestCase {

    private func minimalDocument() -> BackupDocument {
        var document = BackupDocument()
        document.exercises = [
            ExerciseDTO(id: UUID(), name: "Bench Press",
                        primaryMuscleRaw: "chest", secondaryMusclesRaw: [],
                        categoryRaw: "strength", equipmentRaw: "barbell",
                        movementPatternRaw: "horizontalPush",
                        instructions: "", personalNotes: "", isUnilateral: false,
                        usesWeight: true, usesReps: true, usesDuration: false,
                        usesDistance: false, tracksRPE: true, defaultIncrementKg: 2.5,
                        isFavorite: false, favoriteOrder: 0, isArchived: false,
                        isBuiltIn: true, createdAt: Date())
        ]
        document.runs = [
            RunDTO(id: UUID(), date: Date(), runTypeRaw: "easy",
                   distanceMeters: 5000, durationSeconds: 1500,
                   surfaceRaw: "road", routeTypeRaw: "loop",
                   rpe: 6, averageHeartRate: nil, calories: nil,
                   notes: "", intervalStructure: "", source: "manual",
                   healthKitID: nil, splits: [])
        ]
        return document
    }

    // MARK: Round trip

    func testEncodeDecodeRoundTrip() throws {
        let original = minimalDocument()
        let data = try BackupValidator.encode(original)
        let decoded = try BackupValidator.decode(data).get()
        XCTAssertEqual(decoded.schemaVersion, BackupDocument.currentSchemaVersion)
        XCTAssertEqual(decoded.exercises.count, 1)
        XCTAssertEqual(decoded.exercises.first?.name, "Bench Press")
        XCTAssertEqual(decoded.runs.first?.distanceMeters, 5000)
    }

    // MARK: Corruption handling

    func testEmptyDataFails() {
        if case .failure(let error) = BackupValidator.decode(Data()) {
            XCTAssertEqual(error, .unreadableFile)
        } else {
            XCTFail("Empty data must not decode")
        }
    }

    func testGarbageJSONFailsGracefully() {
        let garbage = Data("not json at all {{{".utf8)
        if case .success = BackupValidator.decode(garbage) {
            XCTFail("Garbage must not decode")
        }
    }

    func testFutureSchemaVersionRejected() throws {
        var document = minimalDocument()
        document.schemaVersion = BackupDocument.currentSchemaVersion + 1
        let data = try BackupValidator.encode(document)
        if case .failure(let error) = BackupValidator.decode(data) {
            XCTAssertEqual(error, .unsupportedSchemaVersion(
                found: BackupDocument.currentSchemaVersion + 1,
                supported: BackupDocument.currentSchemaVersion
            ))
        } else {
            XCTFail("Future schema versions must be rejected, not silently mangled")
        }
    }

    // MARK: Semantic validation

    func testDuplicateIDsRejected() {
        var document = minimalDocument()
        document.exercises.append(document.exercises[0])
        if case .success = BackupValidator.validate(document) {
            XCTFail("Duplicate exercise IDs must be rejected")
        }
    }

    func testInvalidRPERejected() {
        var document = minimalDocument()
        document.sessions = [
            SessionDTO(id: UUID(), statusRaw: "completed", name: "Test",
                       startedAt: Date(), completedAt: Date(), pausedSeconds: 0,
                       templateID: nil, templateNameSnapshot: "", notes: "",
                       rating: nil, energy: nil, soreness: nil, readiness: nil,
                       exercises: [
                        WorkoutExerciseDTO(sortIndex: 0, exerciseID: nil, nameSnapshot: "Bench",
                                           primaryMuscleSnapshot: "chest", secondaryMusclesSnapshot: [],
                                           usesWeight: true, usesReps: true, tracksRPE: true,
                                           isUnilateral: false, notes: "", supersetGroup: nil,
                                           sets: [CompletedSetDTO(sortIndex: 0, setTypeRaw: "working",
                                                                  weightKg: 100, reps: 5, rpe: 14,
                                                                  durationSeconds: nil, distanceMeters: nil,
                                                                  isCompleted: true, notes: "", completedAt: nil)])
                       ])
        ]
        if case .success = BackupValidator.validate(document) {
            XCTFail("RPE outside 0–10 must be rejected")
        }
    }

    func testNegativeRunDistanceRejected() {
        var document = minimalDocument()
        document.runs[0].distanceMeters = -100
        if case .success = BackupValidator.validate(document) {
            XCTFail("Negative distances must be rejected")
        }
    }

    func testValidDocumentPassesWithCounts() throws {
        let summary = try BackupValidator.validate(minimalDocument()).get()
        XCTAssertEqual(summary.exerciseCount, 1)
        XCTAssertEqual(summary.runCount, 1)
        XCTAssertTrue(summary.warnings.isEmpty)
    }

    func testMultipleActiveSchedulesProducesWarningNotFailure() throws {
        var document = minimalDocument()
        document.schedules = [
            ScheduleDTO(id: UUID(), name: "A", isActive: true, createdAt: Date(), activities: []),
            ScheduleDTO(id: UUID(), name: "B", isActive: true, createdAt: Date(), activities: []),
        ]
        let summary = try BackupValidator.validate(document).get()
        XCTAssertEqual(summary.warnings.count, 1)
    }

    // MARK: CSV

    func testWorkoutCSVEscapesCommasAndQuotes() {
        let session = SessionDTO(
            id: UUID(), statusRaw: "completed", name: "Push, heavy \"day\"",
            startedAt: Date(), completedAt: Date(), pausedSeconds: 0,
            templateID: nil, templateNameSnapshot: "", notes: "",
            rating: nil, energy: nil, soreness: nil, readiness: nil,
            exercises: [
                WorkoutExerciseDTO(sortIndex: 0, exerciseID: nil, nameSnapshot: "Bench Press",
                                   primaryMuscleSnapshot: "chest", secondaryMusclesSnapshot: [],
                                   usesWeight: true, usesReps: true, tracksRPE: true,
                                   isUnilateral: false, notes: "", supersetGroup: nil,
                                   sets: [CompletedSetDTO(sortIndex: 0, setTypeRaw: "working",
                                                          weightKg: 100, reps: 5, rpe: 8,
                                                          durationSeconds: nil, distanceMeters: nil,
                                                          isCompleted: true, notes: "", completedAt: nil)])
            ]
        )
        let csv = CSVExporter.workoutsCSV(sessions: [session])
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2, "Header plus one set row")
        XCTAssertTrue(lines[1].contains("\"Push, heavy \"\"day\"\"\""), "Fields with commas/quotes must be escaped")
        XCTAssertTrue(lines[0].hasPrefix("date,workout,exercise"))
    }

    func testMeasurementsCSVOrderedByDate() {
        let older = BodyEntryDTO(id: UUID(), date: Date().addingTimeInterval(-86_400),
                                 metricRaw: "bodyWeight", value: 78, notes: "", source: "manual", healthKitID: nil)
        let newer = BodyEntryDTO(id: UUID(), date: Date(),
                                 metricRaw: "bodyWeight", value: 78.4, notes: "", source: "manual", healthKitID: nil)
        let csv = CSVExporter.measurementsCSV(entries: [newer, older])
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[1].contains("78") && !lines[1].contains("78.4"), "Oldest entry must come first")
    }
}
