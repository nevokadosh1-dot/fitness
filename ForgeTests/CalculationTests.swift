import XCTest
@testable import Forge

final class CalculationTests: XCTestCase {

    // MARK: Estimated 1RM

    func testE1RMSingleRepIsWeightItself() {
        XCTAssertEqual(StrengthMath.estimatedOneRM(weightKg: 100, reps: 1), 100)
    }

    func testE1RMFiveRepsIsBetweenEpleyAndBrzycki() {
        let estimate = try! XCTUnwrap(StrengthMath.estimatedOneRM(weightKg: 100, reps: 5))
        let epley = 100 * (1 + 5.0 / 30.0)          // ≈ 116.67
        let brzycki = 100 * 36.0 / (37.0 - 5.0)     // = 112.5
        XCTAssertEqual(estimate, (epley + brzycki) / 2, accuracy: 0.001)
        XCTAssertGreaterThan(estimate, 100)
    }

    func testE1RMInvalidInputsReturnNil() {
        XCTAssertNil(StrengthMath.estimatedOneRM(weightKg: 0, reps: 5))
        XCTAssertNil(StrengthMath.estimatedOneRM(weightKg: -10, reps: 5))
        XCTAssertNil(StrengthMath.estimatedOneRM(weightKg: 100, reps: 0))
        XCTAssertNil(StrengthMath.estimatedOneRM(weightKg: 100, reps: 13),
                     "Formulas are unreliable past 12 reps and must return nil")
    }

    // MARK: Volume & hard sets

    func testVolumeExcludesWarmupsAndIncompleteSets() {
        let sets = [
            SetSnapshot(setTypeRaw: SetType.warmup.rawValue, weightKg: 60, reps: 10, isCompleted: true),
            SetSnapshot(setTypeRaw: SetType.working.rawValue, weightKg: 100, reps: 5, isCompleted: true),
            SetSnapshot(setTypeRaw: SetType.working.rawValue, weightKg: 100, reps: 5, isCompleted: false),
            SetSnapshot(setTypeRaw: SetType.dropSet.rawValue, weightKg: 80, reps: 8, isCompleted: true),
        ]
        XCTAssertEqual(StrengthMath.totalVolumeKg(sets: sets), 100 * 5 + 80 * 8)
        XCTAssertEqual(StrengthMath.hardSetCount(sets: sets), 2)
    }

    func testAverageRPEIgnoresWarmupsAndNils() {
        let sets = [
            SetSnapshot(setTypeRaw: SetType.warmup.rawValue, weightKg: 60, reps: 10, rpe: 5, isCompleted: true),
            SetSnapshot(setTypeRaw: SetType.working.rawValue, weightKg: 100, reps: 5, rpe: 8, isCompleted: true),
            SetSnapshot(setTypeRaw: SetType.working.rawValue, weightKg: 100, reps: 5, rpe: 9, isCompleted: true),
            SetSnapshot(setTypeRaw: SetType.working.rawValue, weightKg: 100, reps: 5, rpe: nil, isCompleted: true),
        ]
        XCTAssertEqual(try XCTUnwrap(StrengthMath.averageRPE(sets: sets)), 8.5, accuracy: 0.001)
    }

    // MARK: Pace

    func testPaceCalculation() {
        // 3 km in 15:00 → 5:00/km = 300 s/km
        let pace = try! XCTUnwrap(RunningMath.paceSecondsPerKm(distanceMeters: 3000, durationSeconds: 900))
        XCTAssertEqual(pace, 300, accuracy: 0.001)
    }

    func testPaceInvalidInputs() {
        XCTAssertNil(RunningMath.paceSecondsPerKm(distanceMeters: 0, durationSeconds: 900))
        XCTAssertNil(RunningMath.paceSecondsPerKm(distanceMeters: 3000, durationSeconds: 0))
    }

    func testDurationFormatting() {
        XCTAssertEqual(RunningMath.formatDuration(895), "14:55")
        XCTAssertEqual(RunningMath.formatDuration(3725), "1:02:05")
        XCTAssertEqual(RunningMath.formatDuration(-5), "—")
    }

    func testPaceFormattingPerKmAndPerMile() {
        XCTAssertEqual(RunningMath.formatPace(secondsPerKm: 300), "5:00 /km")
        // 300 s/km ≈ 482.8 s/mi → 8:03 /mi
        XCTAssertEqual(RunningMath.formatPace(secondsPerKm: 300, unit: .miles), "8:03 /mi")
    }

    func testRiegelPredictionIsConservative() {
        // 5:00 1 km → predicted 3 km should be slower than 15:00 flat (3× the pace).
        let predicted = try! XCTUnwrap(RunningMath.predictTime(knownDistanceMeters: 1000, knownTimeSeconds: 300, targetDistanceMeters: 3000))
        XCTAssertGreaterThan(predicted, 900)
        XCTAssertLessThan(predicted, 1100)
    }

    // MARK: Unit conversion

    func testWeightConversionRoundTrips() {
        let display = UnitsConverter.displayWeight(kg: 100, unit: .pounds)
        XCTAssertEqual(display, 220.462, accuracy: 0.01)
        XCTAssertEqual(UnitsConverter.weightKg(fromDisplay: display, unit: .pounds), 100, accuracy: 0.0001)
    }

    func testDistanceConversionRoundTrips() {
        let miles = UnitsConverter.displayDistance(meters: 5000, unit: .miles)
        XCTAssertEqual(miles, 3.107, accuracy: 0.001)
        XCTAssertEqual(UnitsConverter.distanceMeters(fromDisplay: miles, unit: .miles), 5000, accuracy: 0.01)
    }

    func testLengthConversionRoundTrips() {
        let inches = UnitsConverter.displayLength(cm: 82, unit: .inches)
        XCTAssertEqual(inches, 32.283, accuracy: 0.001)
        XCTAssertEqual(UnitsConverter.lengthCm(fromDisplay: inches, unit: .inches), 82, accuracy: 0.0001)
    }

    // MARK: Trend analysis

    func testLinearFitRecoversSlope() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        // value = 100 + 0.5/day with slight noise-free spacing
        let points = (0..<6).map { day in
            TrendPoint(date: start.addingTimeInterval(Double(day) * 86_400), value: 100 + 0.5 * Double(day))
        }
        let fit = try! XCTUnwrap(TrendAnalysis.linearFit(points))
        XCTAssertEqual(fit.slopePerDay, 0.5, accuracy: 0.0001)
        XCTAssertEqual(fit.rSquared, 1.0, accuracy: 0.0001)
    }

    func testLinearFitRequiresThreePoints() {
        let start = Date()
        let two = [TrendPoint(date: start, value: 1), TrendPoint(date: start.addingTimeInterval(86_400), value: 2)]
        XCTAssertNil(TrendAnalysis.linearFit(two))
    }

    func testTrendDirectionRespectsLowerIsBetter() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        // Run times decreasing by 10 s/week → improving.
        let points = (0..<5).map { week in
            TrendPoint(date: start.addingTimeInterval(Double(week) * 7 * 86_400), value: 900 - Double(week) * 10)
        }
        XCTAssertEqual(TrendAnalysis.direction(of: points, lowerIsBetter: true, meaningfulChangePerWeek: 5), .improving)
        XCTAssertEqual(TrendAnalysis.direction(of: points, lowerIsBetter: false, meaningfulChangePerWeek: 5), .declining)
    }

    func testTrendDirectionFlatForNoise() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let points = [900.0, 901, 899, 900.5, 899.5].enumerated().map { index, value in
            TrendPoint(date: start.addingTimeInterval(Double(index) * 7 * 86_400), value: value)
        }
        XCTAssertEqual(TrendAnalysis.direction(of: points, lowerIsBetter: true, meaningfulChangePerWeek: 5), .flat)
    }

    // MARK: Adherence

    func testCompletionRate() {
        XCTAssertEqual(AdherenceCalculator.completionRate(planned: 4, completed: 3), 0.75)
        XCTAssertEqual(AdherenceCalculator.completionRate(planned: 0, completed: 0), 1,
                       "A week with nothing planned counts as fully adhered")
        XCTAssertEqual(AdherenceCalculator.completionRate(planned: 2, completed: 5), 1,
                       "Rate is capped at 100%")
    }

    func testAverageAdherenceIgnoresEmptyWeeks() {
        let weeks = [
            WeekAdherenceSnapshot(weekStart: Date(), plannedCount: 0, completedCount: 0, skippedCount: 0),
            WeekAdherenceSnapshot(weekStart: Date(), plannedCount: 4, completedCount: 2, skippedCount: 0),
            WeekAdherenceSnapshot(weekStart: Date(), plannedCount: 4, completedCount: 4, skippedCount: 0),
        ]
        XCTAssertEqual(try XCTUnwrap(AdherenceCalculator.averageAdherence(weeks: weeks)), 0.75, accuracy: 0.0001)
    }

    func testWeekStartHonorsFirstWeekday() {
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 15 // a Wednesday
        let calendar = Calendar(identifier: .gregorian)
        let wednesday = calendar.date(from: components)!

        let mondayStart = AdherenceCalculator.weekStart(for: wednesday, firstWeekday: 2, calendar: calendar)
        XCTAssertEqual(calendar.component(.weekday, from: mondayStart), 2)
        let sundayStart = AdherenceCalculator.weekStart(for: wednesday, firstWeekday: 1, calendar: calendar)
        XCTAssertEqual(calendar.component(.weekday, from: sundayStart), 1)
        XCTAssertLessThanOrEqual(mondayStart, wednesday)
        XCTAssertLessThanOrEqual(sundayStart, mondayStart)
    }
}
