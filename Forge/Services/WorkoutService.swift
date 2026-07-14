import Foundation
import SwiftData

/// Session lifecycle: starting (from a template, a past session, or empty),
/// pausing, finishing, discarding, and duplicating. Every mutation is saved
/// immediately — SwiftData persistence doubles as the autosave mechanism.
enum WorkoutService {

    // MARK: Start

    @discardableResult
    static func startSession(template: WorkoutTemplate?, name: String, in context: ModelContext, settings: AppSettings) -> WorkoutSession {
        let session = WorkoutSession(name: template?.name ?? name, template: template)
        context.insert(session)

        if let template {
            for templateExercise in template.orderedExercises {
                let workoutExercise = WorkoutExercise(exercise: templateExercise.exercise, sortIndex: templateExercise.sortIndex)
                if workoutExercise.nameSnapshot.isEmpty {
                    workoutExercise.nameSnapshot = templateExercise.exerciseNameSnapshot
                }
                workoutExercise.supersetGroup = templateExercise.supersetGroup
                workoutExercise.notes = templateExercise.notes
                workoutExercise.session = session
                context.insert(workoutExercise)

                let lastPerformance = previousPerformance(exerciseName: workoutExercise.nameSnapshot, in: context)
                for planned in templateExercise.orderedPlannedSets {
                    let set = CompletedSet(sortIndex: planned.sortIndex, setType: planned.setType)
                    set.targetRepsMin = planned.targetRepsMin
                    set.targetRepsMax = planned.targetRepsMax
                    set.targetWeightKg = planned.targetWeightKg
                    set.targetRPE = planned.targetRPE
                    // Prefill weight from the target, else last session's matching set.
                    if let target = planned.targetWeightKg {
                        set.weightKg = target
                    } else if let last = lastPerformance?.orderedSets.first(where: { $0.sortIndex == planned.sortIndex }) {
                        set.weightKg = last.weightKg
                    }
                    set.workoutExercise = workoutExercise
                    context.insert(set)
                }
            }
        }

        settings.activeWorkoutSessionID = session.id
        try? context.save()
        return session
    }

    /// Starts a fresh session mirroring a past one (same exercises and set layout).
    @discardableResult
    static func startSession(copying past: WorkoutSession, in context: ModelContext, settings: AppSettings) -> WorkoutSession {
        let session = WorkoutSession(name: past.name)
        context.insert(session)
        for pastExercise in past.orderedExercises {
            let exercise = WorkoutExercise(exercise: pastExercise.exercise, sortIndex: pastExercise.sortIndex)
            exercise.nameSnapshot = pastExercise.nameSnapshot
            exercise.primaryMuscleSnapshot = pastExercise.primaryMuscleSnapshot
            exercise.secondaryMusclesSnapshot = pastExercise.secondaryMusclesSnapshot
            exercise.usesWeight = pastExercise.usesWeight
            exercise.usesReps = pastExercise.usesReps
            exercise.tracksRPE = pastExercise.tracksRPE
            exercise.incrementKg = pastExercise.incrementKg
            exercise.isUnilateral = pastExercise.isUnilateral
            exercise.supersetGroup = pastExercise.supersetGroup
            exercise.session = session
            context.insert(exercise)
            for pastSet in pastExercise.orderedSets {
                let set = CompletedSet(sortIndex: pastSet.sortIndex, setType: pastSet.setType)
                set.weightKg = pastSet.weightKg
                set.targetRepsMin = pastSet.reps
                set.workoutExercise = exercise
                context.insert(set)
            }
        }
        settings.activeWorkoutSessionID = session.id
        try? context.save()
        return session
    }

    // MARK: Exercise management within a session

    @discardableResult
    static func addExercise(_ libraryExercise: Exercise, to session: WorkoutSession, in context: ModelContext) -> WorkoutExercise {
        let nextIndex = ((session.exercises ?? []).map(\.sortIndex).max() ?? -1) + 1
        let exercise = WorkoutExercise(exercise: libraryExercise, sortIndex: nextIndex)
        exercise.session = session
        context.insert(exercise)
        addSet(to: exercise, in: context)
        try? context.save()
        return exercise
    }

    @discardableResult
    static func addSet(to exercise: WorkoutExercise, in context: ModelContext) -> CompletedSet {
        let ordered = exercise.orderedSets
        let nextIndex = (ordered.map(\.sortIndex).max() ?? -1) + 1
        let set = CompletedSet(sortIndex: nextIndex)
        if let last = ordered.last {
            set.setTypeRaw = last.setTypeRaw
            set.weightKg = last.weightKg
            set.reps = last.reps
            set.targetRepsMin = last.targetRepsMin
            set.targetRepsMax = last.targetRepsMax
            set.targetWeightKg = last.targetWeightKg
            set.targetRPE = last.targetRPE
        }
        set.workoutExercise = exercise
        context.insert(set)
        try? context.save()
        return set
    }

    /// Most recent completed performance of an exercise, for "last time" hints.
    static func previousPerformance(exerciseName: String, in context: ModelContext, before: Date = Date()) -> WorkoutExercise? {
        guard !exerciseName.isEmpty else { return nil }
        let completedRaw = SessionStatus.completed.rawValue
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == completedRaw && $0.startedAt < before },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        let sessions = (try? context.fetch(descriptor)) ?? []
        for session in sessions {
            if let match = session.orderedExercises.first(where: { $0.displayName == exerciseName }) {
                if (match.sets ?? []).contains(where: \.isCompleted) { return match }
            }
        }
        return nil
    }

    // MARK: Lifecycle

    static func pause(_ session: WorkoutSession, in context: ModelContext) {
        guard session.status == .active else { return }
        session.status = .paused
        session.pauseStartedAt = Date()
        try? context.save()
    }

    static func resume(_ session: WorkoutSession, in context: ModelContext) {
        guard session.status == .paused else { return }
        if let pauseStart = session.pauseStartedAt {
            session.pausedSeconds += Date().timeIntervalSince(pauseStart)
        }
        session.pauseStartedAt = nil
        session.status = .active
        try? context.save()
    }

    static func finish(_ session: WorkoutSession, in context: ModelContext, settings: AppSettings, completedAt: Date = Date()) {
        if session.status == .paused, let pauseStart = session.pauseStartedAt {
            session.pausedSeconds += Date().timeIntervalSince(pauseStart)
            session.pauseStartedAt = nil
        }
        session.completedAt = completedAt
        session.status = .completed
        settings.activeWorkoutSessionID = nil
        try? context.save()
        PRService.recompute(in: context)
    }

    static func discard(_ session: WorkoutSession, in context: ModelContext, settings: AppSettings) {
        settings.activeWorkoutSessionID = nil
        context.delete(session)
        try? context.save()
    }

    static func delete(_ session: WorkoutSession, in context: ModelContext) {
        context.delete(session)
        try? context.save()
        PRService.recompute(in: context)
    }

    // MARK: Template from session

    /// Saves a completed session's structure as a reusable template.
    @discardableResult
    static func saveAsTemplate(_ session: WorkoutSession, name: String, in context: ModelContext) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name)
        template.details = "Created from \(Formatting.mediumDate(session.completedAt ?? session.startedAt))"
        context.insert(template)
        for exercise in session.orderedExercises {
            let templateExercise = TemplateExercise(exercise: exercise.exercise, sortIndex: exercise.sortIndex)
            if templateExercise.exerciseNameSnapshot.isEmpty {
                templateExercise.exerciseNameSnapshot = exercise.nameSnapshot
            }
            templateExercise.supersetGroup = exercise.supersetGroup
            templateExercise.template = template
            context.insert(templateExercise)
            for set in exercise.orderedSets {
                let planned = PlannedSet(sortIndex: set.sortIndex, setType: set.setType)
                planned.targetWeightKg = set.weightKg
                planned.targetRepsMin = set.reps
                planned.targetRepsMax = set.reps
                planned.targetRPE = set.rpe
                planned.templateExercise = templateExercise
                context.insert(planned)
            }
        }
        try? context.save()
        return template
    }
}
