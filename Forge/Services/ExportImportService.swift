import Foundation
import SwiftData

/// Builds backup documents from the store, writes export files, and restores
/// validated backups. Restores merge by ID — existing records are never
/// silently overwritten or destroyed.
enum ExportImportService {

    // MARK: Snapshot store → DTOs

    static func buildBackup(in context: ModelContext, includePhotos: Bool) -> BackupDocument {
        var document = BackupDocument()

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        document.exercises = exercises.map { exercise in
            ExerciseDTO(
                id: exercise.id, name: exercise.name,
                primaryMuscleRaw: exercise.primaryMuscleRaw,
                secondaryMusclesRaw: exercise.secondaryMusclesRaw,
                categoryRaw: exercise.categoryRaw, equipmentRaw: exercise.equipmentRaw,
                movementPatternRaw: exercise.movementPatternRaw,
                instructions: exercise.instructions, personalNotes: exercise.personalNotes,
                isUnilateral: exercise.isUnilateral, usesWeight: exercise.usesWeight,
                usesReps: exercise.usesReps, usesDuration: exercise.usesDuration,
                usesDistance: exercise.usesDistance, tracksRPE: exercise.tracksRPE,
                defaultIncrementKg: exercise.defaultIncrementKg,
                isFavorite: exercise.isFavorite, favoriteOrder: exercise.favoriteOrder,
                isArchived: exercise.isArchived, isBuiltIn: exercise.isBuiltIn,
                createdAt: exercise.createdAt
            )
        }

        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        document.templates = templates.map { template in
            TemplateDTO(
                id: template.id, name: template.name, details: template.details,
                notes: template.notes, colorHex: template.colorHex, iconName: template.iconName,
                estimatedMinutes: template.estimatedMinutes, isArchived: template.isArchived,
                createdAt: template.createdAt,
                exercises: template.orderedExercises.map { templateExercise in
                    TemplateExerciseDTO(
                        sortIndex: templateExercise.sortIndex,
                        exerciseID: templateExercise.exercise?.id,
                        exerciseNameSnapshot: templateExercise.displayName,
                        notes: templateExercise.notes,
                        supersetGroup: templateExercise.supersetGroup,
                        alternativeExerciseIDs: templateExercise.alternativeExerciseIDs,
                        plannedSets: templateExercise.orderedPlannedSets.map { planned in
                            PlannedSetDTO(
                                sortIndex: planned.sortIndex, setTypeRaw: planned.setTypeRaw,
                                targetRepsMin: planned.targetRepsMin, targetRepsMax: planned.targetRepsMax,
                                targetWeightKg: planned.targetWeightKg, targetRPE: planned.targetRPE
                            )
                        }
                    )
                }
            )
        }

        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        document.sessions = sessions.filter { $0.status == .completed }.map(sessionDTO(from:))

        let runs = (try? context.fetch(FetchDescriptor<RunningSession>())) ?? []
        document.runs = runs.map { run in
            RunDTO(
                id: run.id, date: run.date, runTypeRaw: run.runTypeRaw,
                distanceMeters: run.distanceMeters, durationSeconds: run.durationSeconds,
                surfaceRaw: run.surfaceRaw, routeTypeRaw: run.routeTypeRaw,
                rpe: run.rpe, averageHeartRate: run.averageHeartRate, calories: run.calories,
                notes: run.notes, intervalStructure: run.intervalStructure,
                source: run.source, healthKitID: run.healthKitID,
                splits: run.orderedSplits.map {
                    RunSplitDTO(sortIndex: $0.sortIndex, distanceMeters: $0.distanceMeters, durationSeconds: $0.durationSeconds)
                }
            )
        }

        let flexExercises = (try? context.fetch(FetchDescriptor<FlexibilityExercise>())) ?? []
        document.flexibilityExercises = flexExercises.map {
            FlexExerciseDTO(id: $0.id, name: $0.name, instructions: $0.instructions,
                            targetArea: $0.targetArea, isBuiltIn: $0.isBuiltIn,
                            isArchived: $0.isArchived, createdAt: $0.createdAt)
        }

        let routines = (try? context.fetch(FetchDescriptor<FlexibilityRoutine>())) ?? []
        document.flexibilityRoutines = routines.map { routine in
            FlexRoutineDTO(
                id: routine.id, name: routine.name, kindRaw: routine.kindRaw,
                details: routine.details, targetSessionsPerWeek: routine.targetSessionsPerWeek,
                isArchived: routine.isArchived, createdAt: routine.createdAt,
                items: routine.orderedItems.map { item in
                    FlexRoutineItemDTO(
                        sortIndex: item.sortIndex, exerciseID: item.exercise?.id,
                        nameSnapshot: item.displayName, instructionsSnapshot: item.instructionsSnapshot,
                        holdSeconds: item.holdSeconds, sets: item.sets,
                        sideModeRaw: item.sideModeRaw, restSeconds: item.restSeconds, notes: item.notes
                    )
                }
            )
        }

        let flexSessions = (try? context.fetch(FetchDescriptor<FlexibilitySession>())) ?? []
        document.flexibilitySessions = flexSessions.map { session in
            FlexSessionDTO(
                id: session.id, date: session.date, routineID: session.routineID,
                routineNameSnapshot: session.routineNameSnapshot, kindRaw: session.kindRaw,
                durationSeconds: session.durationSeconds, intensity: session.intensity,
                notes: session.notes, statusRaw: session.statusRaw,
                completedItems: (session.completedItems ?? []).sorted { $0.sortIndex < $1.sortIndex }.map {
                    FlexCompletedItemDTO(sortIndex: $0.sortIndex, nameSnapshot: $0.nameSnapshot,
                                         setsCompleted: $0.setsCompleted, setsPlanned: $0.setsPlanned,
                                         holdSeconds: $0.holdSeconds, wasSkipped: $0.wasSkipped)
                }
            )
        }

        let measurements = (try? context.fetch(FetchDescriptor<FlexibilityMeasurement>())) ?? []
        document.flexibilityMeasurements = measurements.map {
            FlexMeasurementDTO(id: $0.id, date: $0.date, targetRaw: $0.targetRaw,
                               methodRaw: $0.methodRaw, value: $0.value, notes: $0.notes)
        }

        let schedules = (try? context.fetch(FetchDescriptor<WeeklySchedule>())) ?? []
        document.schedules = schedules.map { schedule in
            ScheduleDTO(
                id: schedule.id, name: schedule.name, isActive: schedule.isActive,
                createdAt: schedule.createdAt,
                activities: (schedule.activities ?? []).sorted { $0.sortIndex < $1.sortIndex }.map {
                    ScheduledActivityDTO(id: $0.id, weekday: $0.weekday, sortIndex: $0.sortIndex,
                                         kindRaw: $0.kindRaw, title: $0.title,
                                         templateID: $0.templateID, routineID: $0.routineID, notes: $0.notes)
                }
            )
        }

        let overrides = (try? context.fetch(FetchDescriptor<ScheduleOverride>())) ?? []
        document.scheduleOverrides = overrides.map {
            ScheduleOverrideDTO(id: $0.id, weekStart: $0.weekStart, activityID: $0.activityID,
                                statusRaw: $0.statusRaw, movedToWeekday: $0.movedToWeekday,
                                kindRaw: $0.kindRaw, title: $0.title, templateID: $0.templateID,
                                routineID: $0.routineID, completedSessionID: $0.completedSessionID,
                                completedAt: $0.completedAt)
        }

        let bodyEntries = (try? context.fetch(FetchDescriptor<BodyMeasurementEntry>())) ?? []
        document.bodyEntries = bodyEntries.map {
            BodyEntryDTO(id: $0.id, date: $0.date, metricRaw: $0.metricRaw, value: $0.value,
                         notes: $0.notes, source: $0.source, healthKitID: $0.healthKitID)
        }

        let photos = (try? context.fetch(FetchDescriptor<ProgressPhoto>())) ?? []
        document.photos = photos.map { photo in
            PhotoDTO(id: photo.id, date: photo.date, angleRaw: photo.angleRaw,
                     customAngleLabel: photo.customAngleLabel, bodyWeightKg: photo.bodyWeightKg,
                     notes: photo.notes, tags: photo.tags,
                     imageBase64: includePhotos ? photo.imageData.base64EncodedString() : nil)
        }

        if let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            document.settings = SettingsDTO(
                weightUnitRaw: settings.weightUnitRaw, distanceUnitRaw: settings.distanceUnitRaw,
                lengthUnitRaw: settings.lengthUnitRaw, defaultIncrementKg: settings.defaultIncrementKg,
                showRPE: settings.showRPE, firstWeekday: settings.firstWeekday,
                dashboardCardsRaw: settings.dashboardCardsRaw,
                disabledInsightCategories: settings.disabledInsightCategories,
                runningGoalLabel: settings.runningGoalLabel,
                runningGoalDistanceMeters: settings.runningGoalDistanceMeters,
                runningGoalSeconds: settings.runningGoalSeconds,
                customMuscleGroups: settings.customMuscleGroups,
                customEquipment: settings.customEquipment,
                customRunTypes: settings.customRunTypes,
                customStretchAreas: settings.customStretchAreas,
                customBodyMetrics: settings.customBodyMetrics,
                customActivityKinds: settings.customActivityKinds
            )
        }

        return document
    }

    private static func sessionDTO(from session: WorkoutSession) -> SessionDTO {
        SessionDTO(
            id: session.id, statusRaw: session.statusRaw, name: session.name,
            startedAt: session.startedAt, completedAt: session.completedAt,
            pausedSeconds: session.pausedSeconds, templateID: session.templateID,
            templateNameSnapshot: session.templateNameSnapshot, notes: session.notes,
            rating: session.rating, energy: session.energy, soreness: session.soreness,
            readiness: session.readiness,
            exercises: session.orderedExercises.map { exercise in
                WorkoutExerciseDTO(
                    sortIndex: exercise.sortIndex, exerciseID: exercise.exercise?.id,
                    nameSnapshot: exercise.displayName,
                    primaryMuscleSnapshot: exercise.primaryMuscleSnapshot,
                    secondaryMusclesSnapshot: exercise.secondaryMusclesSnapshot,
                    usesWeight: exercise.usesWeight, usesReps: exercise.usesReps,
                    tracksRPE: exercise.tracksRPE, isUnilateral: exercise.isUnilateral,
                    notes: exercise.notes, supersetGroup: exercise.supersetGroup,
                    sets: exercise.orderedSets.map { set in
                        CompletedSetDTO(
                            sortIndex: set.sortIndex, setTypeRaw: set.setTypeRaw,
                            weightKg: set.weightKg, reps: set.reps, rpe: set.rpe,
                            durationSeconds: set.durationSeconds, distanceMeters: set.distanceMeters,
                            isCompleted: set.isCompleted, notes: set.notes, completedAt: set.completedAt
                        )
                    }
                )
            }
        )
    }

    // MARK: Export files

    /// Writes the JSON backup to a temporary file and returns its URL.
    static func exportBackupFile(in context: ModelContext, includePhotos: Bool) throws -> URL {
        let document = buildBackup(in: context, includePhotos: includePhotos)
        let data = try BackupValidator.encode(document)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Forge-Backup-\(formatter.string(from: Date())).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportCSVFiles(in context: ModelContext) throws -> [URL] {
        let document = buildBackup(in: context, includePhotos: false)
        let files: [(String, String)] = [
            ("Forge-Workouts.csv", CSVExporter.workoutsCSV(sessions: document.sessions)),
            ("Forge-Runs.csv", CSVExporter.runsCSV(runs: document.runs)),
            ("Forge-Measurements.csv", CSVExporter.measurementsCSV(entries: document.bodyEntries)),
        ]
        var urls: [URL] = []
        for (name, contents) in files {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try contents.data(using: .utf8)?.write(to: url, options: .atomic)
            urls.append(url)
        }
        return urls
    }

    // MARK: Restore

    struct RestoreResult {
        var imported = 0
        var skippedDuplicates = 0
        var warnings: [String] = []
    }

    /// Merges a validated backup into the store. Records whose ID already
    /// exists are skipped, so restoring the same file twice is harmless.
    @MainActor
    static func restore(_ document: BackupDocument, into context: ModelContext) -> RestoreResult {
        var result = RestoreResult()

        func existingIDs<T: PersistentModel>(_ type: T.Type, id: KeyPath<T, UUID>) -> Set<UUID> {
            let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
            return Set(all.map { $0[keyPath: id] })
        }

        // Exercises first — later entities reference them by ID.
        let exerciseIDs = existingIDs(Exercise.self, id: \.id)
        var exerciseByID: [UUID: Exercise] = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.id, $0) }
        )
        for dto in document.exercises {
            if exerciseIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let exercise = Exercise(name: dto.name)
            exercise.id = dto.id
            exercise.primaryMuscleRaw = dto.primaryMuscleRaw
            exercise.secondaryMusclesRaw = dto.secondaryMusclesRaw
            exercise.categoryRaw = dto.categoryRaw
            exercise.equipmentRaw = dto.equipmentRaw
            exercise.movementPatternRaw = dto.movementPatternRaw
            exercise.instructions = dto.instructions
            exercise.personalNotes = dto.personalNotes
            exercise.isUnilateral = dto.isUnilateral
            exercise.usesWeight = dto.usesWeight
            exercise.usesReps = dto.usesReps
            exercise.usesDuration = dto.usesDuration
            exercise.usesDistance = dto.usesDistance
            exercise.tracksRPE = dto.tracksRPE
            exercise.defaultIncrementKg = dto.defaultIncrementKg
            exercise.isFavorite = dto.isFavorite
            exercise.favoriteOrder = dto.favoriteOrder
            exercise.isArchived = dto.isArchived
            exercise.isBuiltIn = dto.isBuiltIn
            exercise.createdAt = dto.createdAt
            context.insert(exercise)
            exerciseByID[dto.id] = exercise
            result.imported += 1
        }

        let templateIDs = existingIDs(WorkoutTemplate.self, id: \.id)
        for dto in document.templates {
            if templateIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let template = WorkoutTemplate(name: dto.name, details: dto.details,
                                           colorHex: dto.colorHex, iconName: dto.iconName)
            template.id = dto.id
            template.notes = dto.notes
            template.estimatedMinutes = dto.estimatedMinutes
            template.isArchived = dto.isArchived
            template.createdAt = dto.createdAt
            context.insert(template)
            for exerciseDTO in dto.exercises {
                let templateExercise = TemplateExercise(
                    exercise: exerciseDTO.exerciseID.flatMap { exerciseByID[$0] },
                    sortIndex: exerciseDTO.sortIndex
                )
                templateExercise.exerciseNameSnapshot = exerciseDTO.exerciseNameSnapshot
                templateExercise.notes = exerciseDTO.notes
                templateExercise.supersetGroup = exerciseDTO.supersetGroup
                templateExercise.alternativeExerciseIDs = exerciseDTO.alternativeExerciseIDs
                templateExercise.template = template
                context.insert(templateExercise)
                for setDTO in exerciseDTO.plannedSets {
                    let planned = PlannedSet(sortIndex: setDTO.sortIndex,
                                             setType: SetType(rawValue: setDTO.setTypeRaw) ?? .working)
                    planned.targetRepsMin = setDTO.targetRepsMin
                    planned.targetRepsMax = setDTO.targetRepsMax
                    planned.targetWeightKg = setDTO.targetWeightKg
                    planned.targetRPE = setDTO.targetRPE
                    planned.templateExercise = templateExercise
                    context.insert(planned)
                }
            }
            result.imported += 1
        }

        let sessionIDs = existingIDs(WorkoutSession.self, id: \.id)
        for dto in document.sessions {
            if sessionIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let session = WorkoutSession(name: dto.name)
            session.id = dto.id
            session.statusRaw = dto.statusRaw
            session.startedAt = dto.startedAt
            session.completedAt = dto.completedAt
            session.pausedSeconds = dto.pausedSeconds
            session.templateID = dto.templateID
            session.templateNameSnapshot = dto.templateNameSnapshot
            session.notes = dto.notes
            session.rating = dto.rating
            session.energy = dto.energy
            session.soreness = dto.soreness
            session.readiness = dto.readiness
            context.insert(session)
            for exerciseDTO in dto.exercises {
                let exercise = WorkoutExercise(exercise: exerciseDTO.exerciseID.flatMap { exerciseByID[$0] },
                                               sortIndex: exerciseDTO.sortIndex)
                exercise.nameSnapshot = exerciseDTO.nameSnapshot
                exercise.primaryMuscleSnapshot = exerciseDTO.primaryMuscleSnapshot
                exercise.secondaryMusclesSnapshot = exerciseDTO.secondaryMusclesSnapshot
                exercise.usesWeight = exerciseDTO.usesWeight
                exercise.usesReps = exerciseDTO.usesReps
                exercise.tracksRPE = exerciseDTO.tracksRPE
                exercise.isUnilateral = exerciseDTO.isUnilateral
                exercise.notes = exerciseDTO.notes
                exercise.supersetGroup = exerciseDTO.supersetGroup
                exercise.session = session
                context.insert(exercise)
                for setDTO in exerciseDTO.sets {
                    let set = CompletedSet(sortIndex: setDTO.sortIndex,
                                           setType: SetType(rawValue: setDTO.setTypeRaw) ?? .working)
                    set.weightKg = setDTO.weightKg
                    set.reps = setDTO.reps
                    set.rpe = setDTO.rpe
                    set.durationSeconds = setDTO.durationSeconds
                    set.distanceMeters = setDTO.distanceMeters
                    set.isCompleted = setDTO.isCompleted
                    set.notes = setDTO.notes
                    set.completedAt = setDTO.completedAt
                    set.workoutExercise = exercise
                    context.insert(set)
                }
            }
            result.imported += 1
        }

        let runIDs = existingIDs(RunningSession.self, id: \.id)
        for dto in document.runs {
            if runIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let run = RunningSession(date: dto.date, runType: RunType(rawValue: dto.runTypeRaw) ?? .custom,
                                     distanceMeters: dto.distanceMeters, durationSeconds: dto.durationSeconds)
            run.id = dto.id
            run.runTypeRaw = dto.runTypeRaw
            run.surfaceRaw = dto.surfaceRaw
            run.routeTypeRaw = dto.routeTypeRaw
            run.rpe = dto.rpe
            run.averageHeartRate = dto.averageHeartRate
            run.calories = dto.calories
            run.notes = dto.notes
            run.intervalStructure = dto.intervalStructure
            run.source = dto.source
            run.healthKitID = dto.healthKitID
            context.insert(run)
            for splitDTO in dto.splits {
                let split = RunningSplit(sortIndex: splitDTO.sortIndex,
                                         distanceMeters: splitDTO.distanceMeters,
                                         durationSeconds: splitDTO.durationSeconds)
                split.session = run
                context.insert(split)
            }
            result.imported += 1
        }

        let flexExerciseIDs = existingIDs(FlexibilityExercise.self, id: \.id)
        var flexExerciseByID: [UUID: FlexibilityExercise] = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<FlexibilityExercise>())) ?? []).map { ($0.id, $0) }
        )
        for dto in document.flexibilityExercises {
            if flexExerciseIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let exercise = FlexibilityExercise(name: dto.name, instructions: dto.instructions,
                                               targetArea: dto.targetArea, isBuiltIn: dto.isBuiltIn)
            exercise.id = dto.id
            exercise.isArchived = dto.isArchived
            exercise.createdAt = dto.createdAt
            context.insert(exercise)
            flexExerciseByID[dto.id] = exercise
            result.imported += 1
        }

        let routineIDs = existingIDs(FlexibilityRoutine.self, id: \.id)
        for dto in document.flexibilityRoutines {
            if routineIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let routine = FlexibilityRoutine(name: dto.name,
                                             kind: FlexibilityKind(rawValue: dto.kindRaw) ?? .custom,
                                             details: dto.details,
                                             targetSessionsPerWeek: dto.targetSessionsPerWeek)
            routine.id = dto.id
            routine.kindRaw = dto.kindRaw
            routine.isArchived = dto.isArchived
            routine.createdAt = dto.createdAt
            context.insert(routine)
            for itemDTO in dto.items {
                let item = FlexibilityRoutineItem(
                    exercise: itemDTO.exerciseID.flatMap { flexExerciseByID[$0] },
                    sortIndex: itemDTO.sortIndex, holdSeconds: itemDTO.holdSeconds,
                    sets: itemDTO.sets, sideMode: SideMode(rawValue: itemDTO.sideModeRaw) ?? .bilateral,
                    restSeconds: itemDTO.restSeconds
                )
                item.nameSnapshot = itemDTO.nameSnapshot
                item.instructionsSnapshot = itemDTO.instructionsSnapshot
                item.notes = itemDTO.notes
                item.routine = routine
                context.insert(item)
            }
            result.imported += 1
        }

        let flexSessionIDs = existingIDs(FlexibilitySession.self, id: \.id)
        for dto in document.flexibilitySessions {
            if flexSessionIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let session = FlexibilitySession(routine: nil, date: dto.date)
            session.id = dto.id
            session.routineID = dto.routineID
            session.routineNameSnapshot = dto.routineNameSnapshot
            session.kindRaw = dto.kindRaw
            session.durationSeconds = dto.durationSeconds
            session.intensity = dto.intensity
            session.notes = dto.notes
            session.statusRaw = dto.statusRaw
            context.insert(session)
            for itemDTO in dto.completedItems {
                let item = FlexibilityCompletedItem(sortIndex: itemDTO.sortIndex, name: itemDTO.nameSnapshot,
                                                    setsPlanned: itemDTO.setsPlanned, holdSeconds: itemDTO.holdSeconds)
                item.setsCompleted = itemDTO.setsCompleted
                item.wasSkipped = itemDTO.wasSkipped
                item.session = session
                context.insert(item)
            }
            result.imported += 1
        }

        let measurementIDs = existingIDs(FlexibilityMeasurement.self, id: \.id)
        for dto in document.flexibilityMeasurements {
            if measurementIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let measurement = FlexibilityMeasurement(
                date: dto.date,
                target: SplitTarget(rawValue: dto.targetRaw) ?? .middle,
                method: FlexibilityMetricMethod(rawValue: dto.methodRaw) ?? .floorDistance,
                value: dto.value, notes: dto.notes
            )
            measurement.id = dto.id
            context.insert(measurement)
            result.imported += 1
        }

        let scheduleIDs = existingIDs(WeeklySchedule.self, id: \.id)
        let hasActiveSchedule = ((try? context.fetch(FetchDescriptor<WeeklySchedule>())) ?? []).contains(where: \.isActive)
        var restoredActive = hasActiveSchedule
        for dto in document.schedules {
            if scheduleIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let schedule = WeeklySchedule(name: dto.name)
            schedule.id = dto.id
            schedule.isActive = dto.isActive && !restoredActive
            if schedule.isActive { restoredActive = true }
            schedule.createdAt = dto.createdAt
            context.insert(schedule)
            for activityDTO in dto.activities {
                let activity = ScheduledActivity(weekday: activityDTO.weekday, sortIndex: activityDTO.sortIndex,
                                                 kind: ActivityKind(rawValue: activityDTO.kindRaw) ?? .custom,
                                                 title: activityDTO.title)
                activity.id = activityDTO.id
                activity.kindRaw = activityDTO.kindRaw
                activity.templateID = activityDTO.templateID
                activity.routineID = activityDTO.routineID
                activity.notes = activityDTO.notes
                activity.schedule = schedule
                context.insert(activity)
            }
            result.imported += 1
        }

        let overrideIDs = existingIDs(ScheduleOverride.self, id: \.id)
        for dto in document.scheduleOverrides {
            if overrideIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let override = ScheduleOverride(weekStart: dto.weekStart, activityID: dto.activityID)
            override.id = dto.id
            override.statusRaw = dto.statusRaw
            override.movedToWeekday = dto.movedToWeekday
            override.kindRaw = dto.kindRaw
            override.title = dto.title
            override.templateID = dto.templateID
            override.routineID = dto.routineID
            override.completedSessionID = dto.completedSessionID
            override.completedAt = dto.completedAt
            context.insert(override)
            result.imported += 1
        }

        let bodyIDs = existingIDs(BodyMeasurementEntry.self, id: \.id)
        for dto in document.bodyEntries {
            if bodyIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            let entry = BodyMeasurementEntry(date: dto.date, metricRaw: dto.metricRaw, value: dto.value, notes: dto.notes)
            entry.id = dto.id
            entry.source = dto.source
            entry.healthKitID = dto.healthKitID
            context.insert(entry)
            result.imported += 1
        }

        let photoIDs = existingIDs(ProgressPhoto.self, id: \.id)
        for dto in document.photos {
            if photoIDs.contains(dto.id) { result.skippedDuplicates += 1; continue }
            guard let base64 = dto.imageBase64, let imageData = Data(base64Encoded: base64) else {
                result.warnings.append("Photo from \(Formatting.mediumDate(dto.date)) had no image data and was skipped.")
                continue
            }
            let photo = ProgressPhoto(date: dto.date, angle: PhotoAngle(rawValue: dto.angleRaw) ?? .custom,
                                      imageData: imageData,
                                      thumbnailData: ImageProcessor.thumbnailData(from: imageData))
            photo.id = dto.id
            photo.customAngleLabel = dto.customAngleLabel
            photo.bodyWeightKg = dto.bodyWeightKg
            photo.notes = dto.notes
            photo.tags = dto.tags
            context.insert(photo)
            result.imported += 1
        }

        if let settingsDTO = document.settings,
           let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            settings.weightUnitRaw = settingsDTO.weightUnitRaw
            settings.distanceUnitRaw = settingsDTO.distanceUnitRaw
            settings.lengthUnitRaw = settingsDTO.lengthUnitRaw
            settings.defaultIncrementKg = settingsDTO.defaultIncrementKg
            settings.showRPE = settingsDTO.showRPE
            settings.firstWeekday = settingsDTO.firstWeekday
            settings.dashboardCardsRaw = settingsDTO.dashboardCardsRaw
            settings.disabledInsightCategories = settingsDTO.disabledInsightCategories
            settings.runningGoalLabel = settingsDTO.runningGoalLabel
            settings.runningGoalDistanceMeters = settingsDTO.runningGoalDistanceMeters
            settings.runningGoalSeconds = settingsDTO.runningGoalSeconds
            settings.customMuscleGroups = settingsDTO.customMuscleGroups
            settings.customEquipment = settingsDTO.customEquipment
            settings.customRunTypes = settingsDTO.customRunTypes
            settings.customStretchAreas = settingsDTO.customStretchAreas
            settings.customBodyMetrics = settingsDTO.customBodyMetrics
            settings.customActivityKinds = settingsDTO.customActivityKinds
        }

        try? context.save()
        PRService.recompute(in: context)
        return result
    }

    /// Deletes every record. Only reachable behind an explicit typed confirmation.
    @MainActor
    static func deleteAllData(in context: ModelContext) {
        func wipe<T: PersistentModel>(_ type: T.Type) {
            let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
            for item in all { context.delete(item) }
        }
        wipe(WorkoutSession.self)
        wipe(WorkoutTemplate.self)
        wipe(Exercise.self)
        wipe(RunningSession.self)
        wipe(FlexibilitySession.self)
        wipe(FlexibilityRoutine.self)
        wipe(FlexibilityExercise.self)
        wipe(FlexibilityMeasurement.self)
        wipe(WeeklySchedule.self)
        wipe(ScheduleOverride.self)
        wipe(BodyMeasurementEntry.self)
        wipe(ProgressPhoto.self)
        wipe(PersonalRecord.self)
        wipe(Insight.self)
        if let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            settings.seedDataVersion = 0
            settings.activeWorkoutSessionID = nil
        }
        try? context.save()
    }
}
