import XCTest
@testable import Forge

final class PRDetectorTests: XCTestCase {

    private func session(daysAgo: Int, name: String = "Workout",
                         exercises: [ExercisePerformanceSnapshot]) -> SessionSnapshot {
        SessionSnapshot(
            id: UUID(),
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            name: name,
            exercises: exercises
        )
    }

    private func bench(_ weight: Double, _ reps: Int, rpe: Double? = nil) -> ExercisePerformanceSnapshot {
        ExercisePerformanceSnapshot(
            exerciseName: "Bench Press",
            primaryMuscleRaw: MuscleGroup.chest.rawValue,
            sets: [SetSnapshot(weightKg: weight, reps: reps, rpe: rpe, isCompleted: true)]
        )
    }

    // MARK: Strength records

    func testHeaviestWeightRecordPicksTheHeaviestEver() {
        let sessions = [
            session(daysAgo: 20, exercises: [bench(100, 5)]),
            session(daysAgo: 10, exercises: [bench(105, 3)]),
            session(daysAgo: 2, exercises: [bench(102.5, 5)]),
        ]
        let records = PRDetector.strengthRecords(sessions: sessions)
        let heaviest = records.first { $0.kind == .heaviestWeight && $0.subject == "Bench Press" }
        XCTAssertEqual(try XCTUnwrap(heaviest).value, 105)
    }

    func testEstimatedOneRMRecordUsesRepsAndWeight() {
        let sessions = [
            session(daysAgo: 10, exercises: [bench(100, 1)]),   // e1RM 100
            session(daysAgo: 5, exercises: [bench(95, 5)]),     // e1RM ≈ 108.7 — higher
        ]
        let records = PRDetector.strengthRecords(sessions: sessions)
        let e1rm = try! XCTUnwrap(records.first { $0.kind == .estimatedOneRM })
        XCTAssertGreaterThan(e1rm.value, 100)
    }

    func testSessionVolumeRecordTracksBestSingleSession() {
        let small = session(daysAgo: 10, name: "Small", exercises: [bench(100, 5)])   // 500
        let big = session(daysAgo: 5, name: "Big", exercises: [bench(100, 5), bench(100, 5), bench(100, 5)]) // 1500
        let records = PRDetector.strengthRecords(sessions: [small, big])
        let volume = try! XCTUnwrap(records.first { $0.kind == .sessionVolume })
        XCTAssertEqual(volume.value, 1500)
        XCTAssertEqual(volume.subject, "Big")
    }

    func testIncompleteSetsNeverProduceRecords() {
        let exercise = ExercisePerformanceSnapshot(
            exerciseName: "Bench Press",
            sets: [SetSnapshot(weightKg: 200, reps: 5, isCompleted: false)]
        )
        let records = PRDetector.strengthRecords(sessions: [session(daysAgo: 1, exercises: [exercise])])
        XCTAssertTrue(records.filter { $0.kind == .heaviestWeight }.isEmpty)
    }

    // MARK: Running records

    private func run(daysAgo: Int, meters: Double, seconds: Double) -> RunSnapshot {
        RunSnapshot(
            id: UUID(),
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            distanceMeters: meters,
            durationSeconds: seconds
        )
    }

    func testFastest3KRecordMatchesWithinTolerance() {
        let runs = [
            run(daysAgo: 20, meters: 3000, seconds: 950),
            run(daysAgo: 10, meters: 2990, seconds: 920), // within 3K tolerance, faster
            run(daysAgo: 5, meters: 5000, seconds: 1500), // 5K — different benchmark
        ]
        let records = PRDetector.runningRecords(runs: runs)
        let threeK = try! XCTUnwrap(records.first { $0.kind == .fastestTime && $0.subject == "3 km" })
        XCTAssertEqual(threeK.value, 920)
        let fiveK = records.first { $0.kind == .fastestTime && $0.subject == "5 km" }
        XCTAssertEqual(try XCTUnwrap(fiveK).value, 1500)
    }

    func testBestPaceExcludesSprints() {
        let runs = [
            run(daysAgo: 3, meters: 100, seconds: 13),    // sprint — insane pace, must be excluded
            run(daysAgo: 2, meters: 5000, seconds: 1500), // 5:00/km
        ]
        let records = PRDetector.runningRecords(runs: runs)
        let pace = try! XCTUnwrap(records.first { $0.kind == .bestPace })
        XCTAssertEqual(pace.value, 300, accuracy: 0.001)
    }

    func testLongestRunRecord() {
        let runs = [run(daysAgo: 2, meters: 5000, seconds: 1500), run(daysAgo: 1, meters: 12_000, seconds: 4000)]
        let records = PRDetector.runningRecords(runs: runs)
        XCTAssertEqual(try XCTUnwrap(records.first { $0.kind == .longestRun }).value, 12_000)
    }

    // MARK: Flexibility records

    func testFlexibilityBestUsesLowerIsBetterForFloorDistance() {
        let measurements = [
            FlexMeasurementSnapshot(date: Date().addingTimeInterval(-86_400 * 10),
                                    targetRaw: SplitTarget.middle.rawValue,
                                    methodRaw: FlexibilityMetricMethod.floorDistance.rawValue, value: 20),
            FlexMeasurementSnapshot(date: Date(),
                                    targetRaw: SplitTarget.middle.rawValue,
                                    methodRaw: FlexibilityMetricMethod.floorDistance.rawValue, value: 14),
        ]
        let records = PRDetector.flexibilityRecords(measurements: measurements)
        XCTAssertEqual(try XCTUnwrap(records.first { $0.kind == .bestMiddleSplit }).value, 14)
    }

    // MARK: Streak

    func testLongestWeeklyStreakCountsConsecutiveWeeks() {
        let calendar = Calendar.current
        // Sessions in weeks -5, -4, -3 and week -1: longest streak = 3.
        let dates = [-5, -4, -3, -1].map {
            calendar.date(byAdding: .weekOfYear, value: $0, to: Date())!
        }
        let streak = try! XCTUnwrap(PRDetector.longestWeeklyStreak(sessionDates: dates, calendar: calendar))
        XCTAssertEqual(streak.value, 3)
    }

    func testStreakSingleWeek() {
        let streak = try! XCTUnwrap(PRDetector.longestWeeklyStreak(sessionDates: [Date()]))
        XCTAssertEqual(streak.value, 1)
    }

    func testRecordsUpdateWhenHistoryEdited() {
        // Simulates editing a past session: recompute produces the new truth.
        var sessions = [session(daysAgo: 5, exercises: [bench(120, 1)])]
        var records = PRDetector.strengthRecords(sessions: sessions)
        XCTAssertEqual(try XCTUnwrap(records.first { $0.kind == .heaviestWeight }).value, 120)

        // The 120 kg entry is corrected down to 100 kg.
        sessions = [session(daysAgo: 5, exercises: [bench(100, 1)])]
        records = PRDetector.strengthRecords(sessions: sessions)
        XCTAssertEqual(try XCTUnwrap(records.first { $0.kind == .heaviestWeight }).value, 100)
    }
}
