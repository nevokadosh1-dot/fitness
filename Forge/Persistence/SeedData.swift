import Foundation
import SwiftData

/// Inserts the built-in exercise library, starter templates, starter flexibility
/// routines and a starter weekly schedule on first launch. Everything seeded
/// here is fully editable by the user; nothing is ever re-imposed after edits.
enum SeedData {
    static let currentVersion = 1

    static func seedIfNeeded(context: ModelContext) {
        let settings = AppSettings.fetchOrCreate(in: context)
        guard settings.seedDataVersion < currentVersion else { return }

        let exercises = seedExercises(context: context)
        let flexExercises = seedFlexibilityExercises(context: context)
        seedTemplates(context: context, library: exercises)
        seedFlexibilityRoutines(context: context, library: flexExercises)
        seedSchedule(context: context)

        settings.seedDataVersion = currentVersion
        try? context.save()
    }

    // MARK: Strength & cardio exercises

    @discardableResult
    private static func seedExercises(context: ModelContext) -> [String: Exercise] {
        // (name, primary, secondaries, category, equipment, pattern, unilateral, incrementKg)
        let rows: [(String, MuscleGroup, [MuscleGroup], ExerciseCategory, EquipmentType, MovementPattern, Bool, Double)] = [
            ("Back Squat", .quads, [.glutes, .core], .strength, .barbell, .squat, false, 2.5),
            ("Front Squat", .quads, [.core, .glutes], .strength, .barbell, .squat, false, 2.5),
            ("Deadlift", .hamstrings, [.glutes, .back, .forearms], .strength, .barbell, .hinge, false, 5),
            ("Romanian Deadlift", .hamstrings, [.glutes, .back], .strength, .barbell, .hinge, false, 2.5),
            ("Bench Press", .chest, [.triceps, .shoulders], .strength, .barbell, .horizontalPush, false, 2.5),
            ("Incline Bench Press", .chest, [.shoulders, .triceps], .strength, .barbell, .horizontalPush, false, 2.5),
            ("Overhead Press", .shoulders, [.triceps, .core], .strength, .barbell, .verticalPush, false, 1.25),
            ("Barbell Row", .back, [.biceps, .forearms], .strength, .barbell, .horizontalPull, false, 2.5),
            ("Hip Thrust", .glutes, [.hamstrings], .strength, .barbell, .hinge, false, 5),
            ("Bulgarian Split Squat", .quads, [.glutes], .strength, .dumbbell, .lunge, true, 2),
            ("Walking Lunge", .quads, [.glutes, .hamstrings], .strength, .dumbbell, .lunge, true, 2),
            ("Dumbbell Bench Press", .chest, [.triceps, .shoulders], .strength, .dumbbell, .horizontalPush, false, 2),
            ("Dumbbell Shoulder Press", .shoulders, [.triceps], .strength, .dumbbell, .verticalPush, false, 2),
            ("Dumbbell Row", .back, [.biceps], .strength, .dumbbell, .horizontalPull, true, 2),
            ("Lateral Raise", .shoulders, [], .strength, .dumbbell, .isolation, false, 1),
            ("Dumbbell Curl", .biceps, [.forearms], .strength, .dumbbell, .isolation, false, 1),
            ("Hammer Curl", .biceps, [.forearms], .strength, .dumbbell, .isolation, false, 1),
            ("Goblet Squat", .quads, [.glutes, .core], .strength, .kettlebell, .squat, false, 2),
            ("Kettlebell Swing", .glutes, [.hamstrings, .core], .strength, .kettlebell, .hinge, false, 4),
            ("Lat Pulldown", .back, [.biceps], .strength, .cable, .verticalPull, false, 2.5),
            ("Seated Cable Row", .back, [.biceps], .strength, .cable, .horizontalPull, false, 2.5),
            ("Cable Triceps Pushdown", .triceps, [], .strength, .cable, .isolation, false, 2.5),
            ("Cable Fly", .chest, [.shoulders], .strength, .cable, .horizontalPush, false, 2.5),
            ("Face Pull", .shoulders, [.back], .strength, .cable, .horizontalPull, false, 2.5),
            ("Leg Press", .quads, [.glutes], .strength, .machine, .squat, false, 5),
            ("Leg Extension", .quads, [], .strength, .machine, .isolation, false, 2.5),
            ("Seated Leg Curl", .hamstrings, [], .strength, .machine, .isolation, false, 2.5),
            ("Calf Raise", .calves, [], .strength, .machine, .isolation, false, 5),
            ("Hip Adduction Machine", .adductors, [], .strength, .machine, .isolation, false, 2.5),
            ("Pull-up", .back, [.biceps, .core], .bodyweight, .bodyweight, .verticalPull, false, 1.25),
            ("Chin-up", .back, [.biceps], .bodyweight, .bodyweight, .verticalPull, false, 1.25),
            ("Push-up", .chest, [.triceps, .shoulders, .core], .bodyweight, .bodyweight, .horizontalPush, false, 0),
            ("Dip", .chest, [.triceps, .shoulders], .bodyweight, .bodyweight, .verticalPush, false, 1.25),
            ("Nordic Curl", .hamstrings, [.glutes], .bodyweight, .bodyweight, .hinge, false, 0),
            ("Copenhagen Plank", .adductors, [.core], .bodyweight, .bodyweight, .isolation, true, 0),
            ("Hanging Leg Raise", .core, [.hipFlexors, .forearms], .bodyweight, .bodyweight, .isolation, false, 0),
            ("Back Extension", .back, [.glutes, .hamstrings], .bodyweight, .bench, .hinge, false, 0),
        ]

        var byName: [String: Exercise] = [:]
        for row in rows {
            let exercise = Exercise(
                name: row.0, primaryMuscle: row.1, secondaryMuscles: row.2,
                category: row.3, equipment: row.4, movementPattern: row.5,
                isUnilateral: row.6, defaultIncrementKg: row.7, isBuiltIn: true
            )
            if row.3 == .bodyweight {
                exercise.usesWeight = row.7 > 0 // weighted variants allowed via added load
            }
            context.insert(exercise)
            byName[exercise.name] = exercise
        }

        // Timed core work
        let plank = Exercise(name: "Plank", primaryMuscle: .core, category: .bodyweight,
                             equipment: .bodyweight, movementPattern: .isolation,
                             usesWeight: false, usesReps: false, usesDuration: true,
                             tracksRPE: false, defaultIncrementKg: 0, isBuiltIn: true)
        context.insert(plank)
        byName[plank.name] = plank

        return byName
    }

    // MARK: Flexibility exercises

    @discardableResult
    private static func seedFlexibilityExercises(context: ModelContext) -> [String: FlexibilityExercise] {
        let rows: [(String, String, String)] = [
            ("Standing Hamstring Fold", "Hinge at the hips with a long spine and fold over straight legs. Relax the neck; breathe into the stretch.", "Hamstrings"),
            ("Half-Kneeling Hip Flexor Stretch", "Rear knee down, tuck the pelvis, shift gently forward until the front of the rear hip stretches. Keep ribs down.", "Hip Flexors"),
            ("Couch Stretch", "Rear shin up a wall or bench, torso tall. Squeeze the rear glute and tuck the pelvis before deepening.", "Hip Flexors"),
            ("Low Lunge", "Front knee over ankle, rear leg extended, hips sinking forward and down. Hands on floor or blocks.", "Hip Flexors"),
            ("Half Split (Runner's Stretch)", "From a low lunge, straighten the front leg and fold over it with a flat back, hips over the rear knee.", "Hamstrings"),
            ("Front Split Slide", "From half split, slide the front heel forward and the rear knee back, supporting weight on blocks or hands. Stop at strong tension, never pain.", "Front Split"),
            ("Lying Hamstring Stretch (Strap)", "On your back, loop a strap over one foot and draw the straight leg toward you. Keep the other leg long on the floor.", "Hamstrings"),
            ("Pigeon Pose", "Front shin angled under the torso, rear leg extended straight back, hips square. Fold forward for more depth.", "Glutes"),
            ("Butterfly Stretch", "Soles of feet together, knees dropping outward. Hinge forward from the hips with a long spine.", "Adductors"),
            ("Frog Stretch", "Knees wide, ankles in line with knees, hips rocking gently backward. Keep the spine neutral.", "Adductors"),
            ("Pancake Fold", "Seated straddle. Rotate the pelvis forward and walk the hands out, chest reaching toward the floor.", "Adductors"),
            ("Side Lunge (Cossack)", "Shift the hips over one heel with the other leg straight, toes up. Stay tall or hold the floor for balance.", "Adductors"),
            ("Standing Straddle Fold", "Feet wide, fold forward from the hips, hands walking toward the floor or a block.", "Adductors"),
            ("Middle Split Wall Slide", "Lie with hips near a wall, legs up, and let the legs slide open with gravity. Relax and breathe; time does the work.", "Middle Split"),
            ("Seated Middle Split Hold", "Slide the legs apart while supporting weight on hands or blocks. Keep knees and toes pointing up or slightly forward.", "Middle Split"),
            ("Cat-Cow", "On all fours, alternate slowly between rounding and arching the spine with the breath.", "Spine"),
            ("Thread the Needle", "From all fours, slide one arm under the body, resting shoulder and ear on the floor. Rotate through the upper back.", "Spine"),
            ("Down Dog Calf Pedal", "In a down-dog position, bend one knee while pressing the other heel toward the floor, alternating slowly.", "Calves"),
            ("90/90 Hip Switch", "Sit with both legs at 90°. Rotate knees side to side, keeping the chest tall.", "Hips"),
            ("Child's Pose", "Knees wide, big toes together, arms long, forehead to the floor. Breathe slowly.", "Recovery"),
        ]

        var byName: [String: FlexibilityExercise] = [:]
        for row in rows {
            let exercise = FlexibilityExercise(name: row.0, instructions: row.1, targetArea: row.2, isBuiltIn: true)
            context.insert(exercise)
            byName[exercise.name] = exercise
        }
        return byName
    }

    // MARK: Starter templates

    private static func seedTemplates(context: ModelContext, library: [String: Exercise]) {
        // (exercise name, warmups, working sets, reps min, reps max, target RPE)
        func makeTemplate(
            name: String, details: String, colorHex: String, icon: String, minutes: Int,
            rows: [(String, Int, Int, Int, Int, Double)]
        ) {
            let template = WorkoutTemplate(name: name, details: details, colorHex: colorHex, iconName: icon)
            template.estimatedMinutes = minutes
            context.insert(template)
            for (index, row) in rows.enumerated() {
                guard let exercise = library[row.0] else { continue }
                let templateExercise = TemplateExercise(exercise: exercise, sortIndex: index)
                templateExercise.template = template
                context.insert(templateExercise)
                var setIndex = 0
                for _ in 0..<row.1 {
                    let warmup = PlannedSet(sortIndex: setIndex, setType: .warmup)
                    warmup.templateExercise = templateExercise
                    context.insert(warmup)
                    setIndex += 1
                }
                for _ in 0..<row.2 {
                    let set = PlannedSet(sortIndex: setIndex, setType: .working)
                    set.targetRepsMin = row.3
                    set.targetRepsMax = row.4
                    set.targetRPE = row.5
                    set.templateExercise = templateExercise
                    context.insert(set)
                    setIndex += 1
                }
            }
        }

        makeTemplate(
            name: "Upper Body",
            details: "Starter push/pull upper session. Edit freely — sets, targets and exercises are all yours to change.",
            colorHex: "#45AEF5", icon: "figure.strengthtraining.traditional", minutes: 60,
            rows: [
                ("Bench Press", 2, 3, 5, 8, 8),
                ("Barbell Row", 1, 3, 6, 10, 8),
                ("Overhead Press", 1, 3, 6, 10, 8),
                ("Lat Pulldown", 0, 3, 8, 12, 8.5),
                ("Lateral Raise", 0, 3, 12, 15, 9),
                ("Dumbbell Curl", 0, 3, 10, 15, 9),
            ]
        )

        makeTemplate(
            name: "Lower Body",
            details: "Starter squat/hinge lower session with split-support accessories.",
            colorHex: "#4AC766", icon: "figure.strengthtraining.functional", minutes: 65,
            rows: [
                ("Back Squat", 2, 3, 5, 8, 8),
                ("Romanian Deadlift", 1, 3, 6, 10, 8),
                ("Bulgarian Split Squat", 0, 3, 8, 12, 8.5),
                ("Seated Leg Curl", 0, 3, 10, 15, 8.5),
                ("Hip Adduction Machine", 0, 3, 12, 15, 8),
                ("Calf Raise", 0, 4, 10, 15, 9),
            ]
        )
    }

    // MARK: Starter flexibility routines

    private static func seedFlexibilityRoutines(context: ModelContext, library: [String: FlexibilityExercise]) {
        func makeRoutine(
            name: String, kind: FlexibilityKind, details: String, perWeek: Int,
            rows: [(String, Int, Int, SideMode, Int)] // (name, hold, sets, side, rest)
        ) {
            let routine = FlexibilityRoutine(name: name, kind: kind, details: details, targetSessionsPerWeek: perWeek)
            context.insert(routine)
            for (index, row) in rows.enumerated() {
                guard let exercise = library[row.0] else { continue }
                let item = FlexibilityRoutineItem(
                    exercise: exercise, sortIndex: index,
                    holdSeconds: row.1, sets: row.2, sideMode: row.3, restSeconds: row.4
                )
                item.routine = routine
                context.insert(item)
            }
        }

        makeRoutine(
            name: "Front Split Routine", kind: .frontSplit,
            details: "Starter progression toward left and right front splits. Replace or reorder stretches to match your own routine.",
            perWeek: 3,
            rows: [
                ("Half-Kneeling Hip Flexor Stretch", 45, 2, .leftRight, 10),
                ("Couch Stretch", 45, 2, .leftRight, 10),
                ("Standing Hamstring Fold", 45, 2, .bilateral, 10),
                ("Half Split (Runner's Stretch)", 45, 2, .leftRight, 10),
                ("Lying Hamstring Stretch (Strap)", 45, 2, .leftRight, 10),
                ("Pigeon Pose", 45, 2, .leftRight, 10),
                ("Front Split Slide", 60, 3, .leftRight, 30),
            ]
        )

        makeRoutine(
            name: "Middle Split Routine", kind: .middleSplit,
            details: "Starter adductor-focused progression toward the middle split.",
            perWeek: 3,
            rows: [
                ("Butterfly Stretch", 45, 2, .bilateral, 10),
                ("Side Lunge (Cossack)", 30, 2, .leftRight, 10),
                ("Frog Stretch", 60, 3, .bilateral, 20),
                ("Standing Straddle Fold", 45, 2, .bilateral, 10),
                ("Pancake Fold", 45, 3, .bilateral, 20),
                ("Middle Split Wall Slide", 90, 2, .bilateral, 30),
                ("Seated Middle Split Hold", 60, 3, .bilateral, 30),
            ]
        )

        makeRoutine(
            name: "Light Mobility", kind: .mobility,
            details: "Short, easy full-body mobility flow for off days.",
            perWeek: 2,
            rows: [
                ("Cat-Cow", 40, 1, .bilateral, 5),
                ("Thread the Needle", 30, 1, .leftRight, 5),
                ("90/90 Hip Switch", 45, 1, .bilateral, 5),
                ("Down Dog Calf Pedal", 40, 1, .bilateral, 5),
                ("Low Lunge", 30, 1, .leftRight, 5),
                ("Child's Pose", 60, 1, .bilateral, 0),
            ]
        )
    }

    // MARK: Starter weekly schedule

    private static func seedSchedule(context: ModelContext) {
        let schedule = WeeklySchedule(name: "Base Week", isActive: true)
        context.insert(schedule)

        // (weekday 1=Sun…7=Sat, kind, title)
        let rows: [(Int, ActivityKind, String)] = [
            (2, .strength, "Upper Body"),
            (3, .frontSplit, "Front Split Routine"),
            (4, .running, "Easy Run"),
            (5, .strength, "Lower Body"),
            (6, .middleSplit, "Middle Split Routine"),
            (7, .running, "Long Run"),
            (1, .rest, "Rest Day"),
        ]
        for (index, row) in rows.enumerated() {
            let activity = ScheduledActivity(weekday: row.0, sortIndex: index, kind: row.1, title: row.2)
            activity.schedule = schedule
            context.insert(activity)
        }
    }
}
