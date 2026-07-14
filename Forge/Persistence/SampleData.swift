import Foundation
import SwiftData

/// Realistic sample history for previews, development and UI tests only.
/// Never inserted into the production store without explicit user action.
enum SampleData {

    static func insert(into context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }

        // Strength history: six weeks of alternating upper/lower with gentle progression.
        let benchWeights: [Double] = [80, 80, 82.5, 82.5, 85, 85]
        let squatWeights: [Double] = [110, 112.5, 115, 115, 117.5, 120]
        for week in 0..<6 {
            let upper = WorkoutSession(name: "Upper Body")
            upper.startedAt = daysAgo(42 - week * 7)
            upper.completedAt = upper.startedAt.addingTimeInterval(3600)
            upper.status = .completed
            context.insert(upper)
            addExercise(to: upper, context: context, name: "Bench Press", muscle: .chest,
                        sets: (0..<3).map { _ in (benchWeights[week], 6, 8.0) })
            addExercise(to: upper, context: context, name: "Barbell Row", muscle: .back,
                        sets: (0..<3).map { _ in (70 + Double(week), 8, 8.0) })

            let lower = WorkoutSession(name: "Lower Body")
            lower.startedAt = daysAgo(39 - week * 7)
            lower.completedAt = lower.startedAt.addingTimeInterval(3900)
            lower.status = .completed
            context.insert(lower)
            addExercise(to: lower, context: context, name: "Back Squat", muscle: .quads,
                        sets: (0..<3).map { _ in (squatWeights[week], 5, 8.5) })
            addExercise(to: lower, context: context, name: "Romanian Deadlift", muscle: .hamstrings,
                        sets: (0..<3).map { _ in (90, 8, 8.0) })
        }

        // Running history including 3 km benchmark efforts.
        let threeKTimes: [Double] = [15 * 60 + 40, 15 * 60 + 12, 14 * 60 + 55]
        for (index, time) in threeKTimes.enumerated() {
            let run = RunningSession(date: daysAgo(35 - index * 14), runType: .timeTrial,
                                     distanceMeters: 3000, durationSeconds: time)
            run.rpe = 9
            context.insert(run)
        }
        for week in 0..<5 {
            let easy = RunningSession(date: daysAgo(33 - week * 7), runType: .easy,
                                      distanceMeters: 5200, durationSeconds: 32 * 60)
            easy.rpe = 5
            context.insert(easy)
        }

        // Flexibility sessions and split measurements trending down (closer to floor).
        for week in 0..<6 {
            let flex = FlexibilitySession(routine: nil, date: daysAgo(40 - week * 7))
            flex.routineNameSnapshot = "Front Split Routine"
            flex.kind = .frontSplit
            flex.durationSeconds = 25 * 60
            flex.intensity = 6
            context.insert(flex)

            let left = FlexibilityMeasurement(date: daysAgo(40 - week * 7), target: .leftFront,
                                              method: .floorDistance, value: 24 - Double(week) * 1.5)
            let right = FlexibilityMeasurement(date: daysAgo(40 - week * 7), target: .rightFront,
                                               method: .floorDistance, value: 28 - Double(week) * 1.2)
            context.insert(left)
            context.insert(right)
        }

        // Body weight drifting up slowly plus a few girth measurements.
        for day in stride(from: 42, through: 0, by: -3) {
            let entry = BodyMeasurementEntry(date: daysAgo(day), metricRaw: BodyMetric.bodyWeight.rawValue,
                                             value: 78.0 + Double(42 - day) * 0.03)
            context.insert(entry)
        }
        context.insert(BodyMeasurementEntry(date: daysAgo(30), metricRaw: BodyMetric.waist.rawValue, value: 82))
        context.insert(BodyMeasurementEntry(date: daysAgo(2), metricRaw: BodyMetric.waist.rawValue, value: 81.2))

        try? context.save()
    }

    private static func addExercise(
        to session: WorkoutSession, context: ModelContext,
        name: String, muscle: MuscleGroup,
        sets: [(weight: Double, reps: Int, rpe: Double)]
    ) {
        let exercise = WorkoutExercise(exercise: nil, sortIndex: session.exercises?.count ?? 0)
        exercise.nameSnapshot = name
        exercise.primaryMuscleSnapshot = muscle.rawValue
        exercise.session = session
        context.insert(exercise)
        for (index, row) in sets.enumerated() {
            let set = CompletedSet(sortIndex: index)
            set.weightKg = row.weight
            set.reps = row.reps
            set.rpe = row.rpe
            set.isCompleted = true
            set.completedAt = session.startedAt.addingTimeInterval(Double(index) * 180)
            set.workoutExercise = exercise
            context.insert(set)
        }
    }
}
