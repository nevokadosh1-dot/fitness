import XCTest
import SwiftData
@testable import Forge

/// End-to-end tests against a fresh in-memory SwiftData store.
@MainActor
final class StoreIntegrationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var settings: AppSettings!

    override func setUp() async throws {
        let result = ModelContainerFactory.makeContainer(inMemory: true)
        container = result.container
        context = container.mainContext
        settings = AppSettings.fetchOrCreate(in: context)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        settings = nil
    }

    // MARK: Seeding

    func testSeedDataCreatesLibraryAndTemplates() throws {
        SeedData.seedIfNeeded(context: context)
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let routines = try context.fetch(FetchDescriptor<FlexibilityRoutine>())
        let schedules = try context.fetch(FetchDescriptor<WeeklySchedule>())
        XCTAssertGreaterThan(exercises.count, 30)
        XCTAssertEqual(templates.count, 2)
        XCTAssertEqual(routines.count, 3)
        XCTAssertEqual(schedules.count, 1)
        XCTAssertTrue(routines.contains { $0.kind == .frontSplit })
        XCTAssertTrue(routines.contains { $0.kind == .middleSplit })

        // Seeding twice must not duplicate.
        SeedData.seedIfNeeded(context: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutTemplate>()).count, 2)
    }

    // MARK: Session lifecycle & autosave recovery

    func testStartSessionFromTemplatePrefillsTargets() throws {
        SeedData.seedIfNeeded(context: context)
        let template = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutTemplate>()).first)
        let session = WorkoutService.startSession(template: template, name: template.name, in: context, settings: settings)

        XCTAssertEqual(session.status, .active)
        XCTAssertEqual(session.exercises?.count, template.exercises?.count)
        XCTAssertEqual(settings.activeWorkoutSessionID, session.id)
        let firstSet = try XCTUnwrap(session.orderedExercises.first?.orderedSets.first)
        XCTAssertNotNil(firstSet.setTypeRaw)
    }

    func testActiveSessionIsRecoverable() throws {
        let session = WorkoutService.startSession(template: nil, name: "Late Night", in: context, settings: settings)
        // Simulate relaunch: query for an unfinished session.
        let recovered = StoreQueries.activeSession(in: context)
        XCTAssertEqual(recovered?.id, session.id)

        WorkoutService.finish(session, in: context, settings: settings)
        XCTAssertNil(StoreQueries.activeSession(in: context))
        XCTAssertNil(settings.activeWorkoutSessionID)
    }

    func testPauseExcludedFromDuration() throws {
        let session = WorkoutService.startSession(template: nil, name: "Test", in: context, settings: settings)
        session.startedAt = Date().addingTimeInterval(-600) // 10 minutes ago
        WorkoutService.pause(session, in: context)
        session.pauseStartedAt = Date().addingTimeInterval(-300) // paused 5 minutes ago
        WorkoutService.resume(session, in: context)
        // ~5 minutes of active time remain.
        XCTAssertEqual(session.duration, 300, accuracy: 5)
    }

    func testFinishComputesRecords() throws {
        let session = WorkoutService.startSession(template: nil, name: "PR Day", in: context, settings: settings)
        let exercise = WorkoutExercise(exercise: nil, sortIndex: 0)
        exercise.nameSnapshot = "Bench Press"
        exercise.session = session
        context.insert(exercise)
        let set = CompletedSet(sortIndex: 0)
        set.weightKg = 110
        set.reps = 3
        set.isCompleted = true
        set.workoutExercise = exercise
        context.insert(set)

        WorkoutService.finish(session, in: context, settings: settings)
        let records = try context.fetch(FetchDescriptor<PersonalRecord>())
        XCTAssertTrue(records.contains { $0.kind == .heaviestWeight && $0.subject == "Bench Press" && $0.value == 110 })
    }

    func testTemplateEditsDoNotAlterHistory() throws {
        SeedData.seedIfNeeded(context: context)
        let template = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutTemplate>()).first)
        let originalTemplateName = template.name
        let session = WorkoutService.startSession(template: template, name: template.name, in: context, settings: settings)
        let historicalName = try XCTUnwrap(session.orderedExercises.first?.displayName)
        WorkoutService.finish(session, in: context, settings: settings)

        // Rename the template and its first exercise's library entry.
        template.name = "Renamed Template"
        let libraryExercise = try XCTUnwrap(template.orderedExercises.first?.exercise)
        libraryExercise.name = "Totally Different"
        try context.save()

        // The session snapshots must still show the historical names.
        XCTAssertEqual(session.orderedExercises.first?.nameSnapshot, historicalName)
        XCTAssertNotEqual(historicalName, "Totally Different")
        XCTAssertEqual(session.templateNameSnapshot, originalTemplateName)
    }

    // MARK: Schedule resolution

    func testWeekResolutionAutoCompletesFromLoggedSessions() throws {
        SeedData.seedIfNeeded(context: context)
        let weekStart = AdherenceCalculator.weekStart(for: Date(), firstWeekday: settings.firstWeekday)

        // Log a strength workout today.
        let session = WorkoutService.startSession(template: nil, name: "Logged", in: context, settings: settings)
        WorkoutService.finish(session, in: context, settings: settings)

        let week = ScheduleService.resolveWeek(containing: Date(), in: context, settings: settings)
        let today = Calendar.current.startOfDay(for: Date())
        let todayActivities = week.activities(on: today)
        // If the seeded plan has a strength session today it must be auto-completed.
        if let strength = todayActivities.first(where: { $0.kind == .strength }) {
            XCTAssertEqual(strength.status, .completed)
            XCTAssertTrue(strength.autoCompleted)
        }
        XCTAssertEqual(week.weekStart, weekStart)
        XCTAssertEqual(week.days.count, 7)
    }

    func testSkipAndMoveCreateOverridesWithoutTouchingPreset() throws {
        SeedData.seedIfNeeded(context: context)
        let schedule = try XCTUnwrap(ScheduleService.activeSchedule(in: context))
        let originalActivityCount = schedule.activities?.count ?? 0

        let week = ScheduleService.resolveWeek(containing: Date(), in: context, settings: settings)
        let activity = try XCTUnwrap(week.activities.first { $0.kind != .rest })

        ScheduleService.skip(activity, weekStart: week.weekStart, in: context)
        let resolved = ScheduleService.resolveWeek(containing: Date(), in: context, settings: settings)
        XCTAssertEqual(resolved.activities.first { $0.id == activity.id }?.status, .skipped)
        XCTAssertEqual(schedule.activities?.count, originalActivityCount, "Preset must not change")

        // Next week is unaffected.
        let nextWeekDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!
        let nextWeek = ScheduleService.resolveWeek(containing: nextWeekDate, in: context, settings: settings)
        XCTAssertEqual(nextWeek.activities.first { $0.baseActivityID == activity.baseActivityID }?.status, .planned)
    }

    func testAdHocActivityAppearsOnlyInItsWeek() throws {
        SeedData.seedIfNeeded(context: context)
        let week = ScheduleService.resolveWeek(containing: Date(), in: context, settings: settings)
        let weekday = Calendar.current.component(.weekday, from: Date())
        ScheduleService.addOneOff(kind: .running, title: "Extra Tempo", weekday: weekday,
                                  weekStart: week.weekStart, in: context)

        let resolved = ScheduleService.resolveWeek(containing: Date(), in: context, settings: settings)
        XCTAssertTrue(resolved.activities.contains { $0.title == "Extra Tempo" && $0.isAdHoc })

        let nextWeekDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!
        let nextWeek = ScheduleService.resolveWeek(containing: nextWeekDate, in: context, settings: settings)
        XCTAssertFalse(nextWeek.activities.contains { $0.title == "Extra Tempo" })
    }

    // MARK: Backup restore merge

    func testRestoreSkipsDuplicatesAndImportsNew() throws {
        SeedData.seedIfNeeded(context: context)
        let run = RunningSession(date: Date(), runType: .easy, distanceMeters: 5000, durationSeconds: 1500)
        context.insert(run)
        try context.save()

        // Export, then restore into the same store: everything is a duplicate.
        let document = ExportImportService.buildBackup(in: context, includePhotos: false)
        let sameStore = ExportImportService.restore(document, into: context)
        XCTAssertEqual(sameStore.imported, 0)
        XCTAssertGreaterThan(sameStore.skippedDuplicates, 0)

        // A new record in the document is imported.
        var enriched = document
        enriched.runs.append(RunDTO(id: UUID(), date: Date(), runTypeRaw: "tempo",
                                    distanceMeters: 3000, durationSeconds: 900,
                                    surfaceRaw: "track", routeTypeRaw: "laps",
                                    rpe: 9, averageHeartRate: nil, calories: nil,
                                    notes: "", intervalStructure: "", source: "manual",
                                    healthKitID: nil, splits: []))
        let merged = ExportImportService.restore(enriched, into: context)
        XCTAssertEqual(merged.imported, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<RunningSession>()).count, 2)
    }

    func testDeleteAllDataLeavesEmptyStore() throws {
        SeedData.seedIfNeeded(context: context)
        let session = WorkoutService.startSession(template: nil, name: "Doomed", in: context, settings: settings)
        WorkoutService.finish(session, in: context, settings: settings)

        ExportImportService.deleteAllData(in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutSession>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PersonalRecord>()).count, 0)
        // Settings row survives so preferences (like units) persist.
        XCTAssertEqual(try context.fetch(FetchDescriptor<AppSettings>()).count, 1)
    }
}
