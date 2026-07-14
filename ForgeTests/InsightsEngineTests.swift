import XCTest
@testable import Forge

final class InsightsEngineTests: XCTestCase {

    private func session(daysAgo: Int, exerciseName: String,
                         sets: [SetSnapshot]) -> SessionSnapshot {
        SessionSnapshot(
            id: UUID(),
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            name: "Workout",
            exercises: [ExercisePerformanceSnapshot(exerciseName: exerciseName,
                                                    primaryMuscleRaw: MuscleGroup.chest.rawValue,
                                                    sets: sets)]
        )
    }

    private func workingSets(weight: Double, reps: Int, rpe: Double?) -> [SetSnapshot] {
        (0..<3).map { _ in SetSnapshot(weightKg: weight, reps: reps, rpe: rpe, isCompleted: true) }
    }

    // MARK: Progressive overload

    func testOverloadSuggestedAfterTwoSolidSessionsAtSameWeight() {
        var context = InsightContext()
        context.sessions = [
            session(daysAgo: 7, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 7.5)),
            session(daysAgo: 2, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 7.5)),
        ]
        let results = ProgressiveOverloadRule().evaluate(context)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.category, .progressiveOverload)
        XCTAssertFalse(results.first?.evidence.isEmpty ?? true, "Insights must show their evidence")
    }

    func testNoOverloadSuggestionWhenRPEIsHigh() {
        var context = InsightContext()
        context.sessions = [
            session(daysAgo: 7, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 9.5)),
            session(daysAgo: 2, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 9.5)),
        ]
        XCTAssertTrue(ProgressiveOverloadRule().evaluate(context).isEmpty)
    }

    func testNoOverloadSuggestionWhenRepsDropped() {
        var context = InsightContext()
        context.sessions = [
            session(daysAgo: 7, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 7)),
            session(daysAgo: 2, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 6, rpe: 7)),
        ]
        XCTAssertTrue(ProgressiveOverloadRule().evaluate(context).isEmpty)
    }

    func testNoOverloadSuggestionWhenWeightChanged() {
        var context = InsightContext()
        context.sessions = [
            session(daysAgo: 7, exerciseName: "Bench Press", sets: workingSets(weight: 97.5, reps: 8, rpe: 7)),
            session(daysAgo: 2, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 7)),
        ]
        XCTAssertTrue(ProgressiveOverloadRule().evaluate(context).isEmpty)
    }

    // MARK: Stall detection

    func testStallDetectedWhenE1RMFlatAcrossThreeSessions() {
        var context = InsightContext()
        context.sessions = [
            session(daysAgo: 21, exerciseName: "Squat", sets: workingSets(weight: 140, reps: 5, rpe: 9)),
            session(daysAgo: 14, exerciseName: "Squat", sets: workingSets(weight: 140, reps: 5, rpe: 9)),
            session(daysAgo: 7, exerciseName: "Squat", sets: workingSets(weight: 140, reps: 5, rpe: 9)),
        ]
        let results = StalledExerciseRule().evaluate(context)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.category, .stalling)
    }

    func testNoStallWhenProgressing() {
        var context = InsightContext()
        context.sessions = [
            session(daysAgo: 21, exerciseName: "Squat", sets: workingSets(weight: 140, reps: 5, rpe: 8)),
            session(daysAgo: 14, exerciseName: "Squat", sets: workingSets(weight: 145, reps: 5, rpe: 8)),
            session(daysAgo: 7, exerciseName: "Squat", sets: workingSets(weight: 150, reps: 5, rpe: 8)),
        ]
        XCTAssertTrue(StalledExerciseRule().evaluate(context).isEmpty)
    }

    // MARK: High RPE

    func testHighRPEWithFallingOutputFlagged() {
        var context = InsightContext()
        context.sessions = [
            session(daysAgo: 14, exerciseName: "Deadlift", sets: workingSets(weight: 180, reps: 5, rpe: 8)),
            session(daysAgo: 7, exerciseName: "Deadlift", sets: workingSets(weight: 180, reps: 4, rpe: 8.5)),
            session(daysAgo: 2, exerciseName: "Deadlift", sets: workingSets(weight: 180, reps: 4, rpe: 9)),
        ]
        let results = HighRPERule().evaluate(context)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.category, .highFatigue)
    }

    // MARK: Missed sessions

    func testMissedSessionsPatternDetected() {
        var context = InsightContext()
        let calendar = Calendar.current
        context.adherenceWeeks = [-2, -1].map { offset in
            WeekAdherenceSnapshot(
                weekStart: calendar.date(byAdding: .weekOfYear, value: offset, to: Date())!,
                plannedCount: 5, completedCount: 2, skippedCount: 0
            )
        }
        let results = MissedSessionsRule().evaluate(context)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.category, .consistency)
    }

    func testNoMissedSessionsInsightWhenAdherenceIsGood() {
        var context = InsightContext()
        context.adherenceWeeks = [
            WeekAdherenceSnapshot(weekStart: Date(), plannedCount: 5, completedCount: 5, skippedCount: 0),
            WeekAdherenceSnapshot(weekStart: Date(), plannedCount: 5, completedCount: 4, skippedCount: 0),
        ]
        XCTAssertTrue(MissedSessionsRule().evaluate(context).isEmpty)
    }

    // MARK: Category filtering & dismissal fingerprints

    func testEngineRespectsDisabledCategories() {
        var context = InsightContext()
        context.sessions = [
            session(daysAgo: 7, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 7)),
            session(daysAgo: 2, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 7)),
        ]
        let engine = InsightsEngine()
        let withCategory = engine.generate(context: context, enabledCategories: [.progressiveOverload])
        let withoutCategory = engine.generate(context: context, enabledCategories: [.running])
        XCTAssertFalse(withCategory.isEmpty)
        XCTAssertTrue(withoutCategory.isEmpty)
    }

    func testFingerprintsAreStableForSameEvidence() {
        var context = InsightContext()
        context.sessions = [
            session(daysAgo: 7, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 7)),
            session(daysAgo: 2, exerciseName: "Bench Press", sets: workingSets(weight: 100, reps: 8, rpe: 7)),
        ]
        let first = ProgressiveOverloadRule().evaluate(context).first?.fingerprint
        let second = ProgressiveOverloadRule().evaluate(context).first?.fingerprint
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second, "Stable fingerprints are required for dismissals to persist")
    }

    // MARK: Running trend

    private func timedRun(daysAgo: Int, seconds: Double) -> RunSnapshot {
        RunSnapshot(
            id: UUID(),
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            distanceMeters: 3000,
            durationSeconds: seconds,
            runTypeRaw: RunType.timeTrial.rawValue
        )
    }

    func testRunningImprovementDetected() {
        var context = InsightContext()
        context.runs = [
            timedRun(daysAgo: 60, seconds: 960),
            timedRun(daysAgo: 40, seconds: 940),
            timedRun(daysAgo: 20, seconds: 915),
            timedRun(daysAgo: 5, seconds: 895),
        ]
        let results = RunningTrendRule().evaluate(context)
        XCTAssertTrue(results.contains { $0.title.contains("trending faster") })
    }

    func testTwoRunsProduceInsufficientDataMessageNotPrediction() {
        var context = InsightContext()
        context.runs = [timedRun(daysAgo: 20, seconds: 960), timedRun(daysAgo: 5, seconds: 940)]
        let results = RunningTrendRule().evaluate(context)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.body.contains("not enough data") ?? false)
    }

    // MARK: Projection is conservative

    func testProjectionCappedAtFourPercent() {
        var context = InsightContext()
        // Absurdly steep progress: +5 kg e1RM per session, twice weekly.
        context.sessions = (0..<6).map { index in
            session(daysAgo: 60 - index * 10, exerciseName: "Bench Press",
                    sets: workingSets(weight: 100 + Double(index) * 5, reps: 5, rpe: 8))
        }
        let results = ProjectionRule().evaluate(context)
        guard let projection = results.first else {
            XCTFail("Expected a projection for steadily progressing lift")
            return
        }
        // Latest e1RM ≈ 125 × formula factor; the projection must not exceed +4%.
        let lastE1RM = try! XCTUnwrap(StrengthMath.estimatedOneRM(weightKg: 125, reps: 5))
        let projectedValue = Double(projection.title
            .components(separatedBy: "≈ ").last?
            .components(separatedBy: " kg").first?
            .replacingOccurrences(of: ",", with: "") ?? "")
        if let projectedValue {
            XCTAssertLessThanOrEqual(projectedValue, lastE1RM * 1.041)
        }
        XCTAssertTrue(projection.body.contains("estimate"), "Projections must be labeled as estimates")
    }

    // MARK: Flexibility consistency

    func testFlexibilityShortfallReportedLateInWeek() {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        var context = InsightContext()
        context.calendar = calendar
        // Force "now" to the 6th day of the week so the rule is active.
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        context.now = calendar.date(byAdding: .day, value: 5, to: weekStart)!
        context.flexTargetsPerWeek = [FlexibilityKind.frontSplit.rawValue: 3]
        context.flexSessions = [
            FlexSessionSnapshot(id: UUID(), date: weekStart.addingTimeInterval(3600),
                                kindRaw: FlexibilityKind.frontSplit.rawValue)
        ]
        let results = FlexibilityConsistencyRule().evaluate(context)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.title.contains("1 of 3") ?? false)
    }
}
