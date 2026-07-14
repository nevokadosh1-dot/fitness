import Foundation
import SwiftData

enum ModelContainerFactory {

    static let allModelTypes: [any PersistentModel.Type] = [
        Exercise.self,
        WorkoutTemplate.self, TemplateExercise.self, PlannedSet.self,
        WorkoutSession.self, WorkoutExercise.self, CompletedSet.self,
        RunningSession.self, RunningSplit.self,
        FlexibilityExercise.self, FlexibilityRoutine.self, FlexibilityRoutineItem.self,
        FlexibilitySession.self, FlexibilityCompletedItem.self, FlexibilityMeasurement.self,
        WeeklySchedule.self, ScheduledActivity.self, ScheduleOverride.self,
        BodyMeasurementEntry.self, ProgressPhoto.self,
        PersonalRecord.self, Insight.self,
        AppSettings.self,
    ]

    static var schema: Schema { Schema(allModelTypes) }

    /// Creates the production container; falls back to in-memory storage if the
    /// on-disk store cannot be opened so the app still launches with an
    /// explanation instead of crashing.
    static func makeContainer(inMemory: Bool = false) -> (container: ModelContainer, loadError: String?) {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return (container, nil)
        } catch {
            // Retry in memory so the UI can present the failure gracefully.
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                let fallback = try ModelContainer(for: schema, configurations: [fallbackConfig])
                return (fallback, "Your data store could not be opened (\(error.localizedDescription)). Forge is running without persistence — restart the app; if this persists, restore from a backup.")
            } catch {
                fatalError("Unable to create even an in-memory model container: \(error)")
            }
        }
    }

    /// Fresh in-memory container for previews and UI tests.
    @MainActor
    static func preview(seeded: Bool = true, sampleData: Bool = false) -> ModelContainer {
        let (container, _) = makeContainer(inMemory: true)
        if seeded {
            SeedData.seedIfNeeded(context: container.mainContext)
        }
        if sampleData {
            SampleData.insert(into: container.mainContext)
        }
        return container
    }
}
