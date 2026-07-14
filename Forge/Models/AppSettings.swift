import Foundation
import SwiftData

/// Identifiers for the dashboard cards the user can show, hide and reorder.
enum DashboardCard: String, Codable, CaseIterable, Identifiable {
    case todayPlan, weekStatus, lastWorkout, bodyWeight, recentPRs
    case running, frontSplit, middleSplit, readiness, suggestion

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .todayPlan: return "Today's Plan"
        case .weekStatus: return "Weekly Status"
        case .lastWorkout: return "Last Workout"
        case .bodyWeight: return "Body Weight Trend"
        case .recentPRs: return "Recent Records"
        case .running: return "Running Progress"
        case .frontSplit: return "Front Split"
        case .middleSplit: return "Middle Split"
        case .readiness: return "Readiness"
        case .suggestion: return "Suggested Next Action"
        }
    }
}

/// Single-row settings object. Fetch through `AppSettings.fetchOrCreate(in:)`.
@Model
final class AppSettings {
    // Units & defaults
    var weightUnitRaw: String = WeightUnit.kilograms.rawValue
    var distanceUnitRaw: String = DistanceUnit.kilometers.rawValue
    var lengthUnitRaw: String = LengthUnit.centimeters.rawValue
    var defaultIncrementKg: Double = 2.5
    var showRPE: Bool = true
    /// Calendar weekday number for the first day of the week (1 = Sunday, 2 = Monday).
    var firstWeekday: Int = 2

    // Appearance & feel
    var appearanceRaw: String = AppAppearance.dark.rawValue
    var hapticsEnabled: Bool = true

    // Privacy & integrations
    var appLockEnabled: Bool = false
    var healthKitEnabled: Bool = false
    var healthKitWriteWorkouts: Bool = false
    var lastHealthKitImport: Date?
    var iCloudSyncNote: Bool = false

    // Notifications (all opt-in)
    var notifyScheduledWorkouts: Bool = false
    var notifyMissedSessions: Bool = false
    var notifyBodyWeightLogging: Bool = false
    var notifyFlexibilitySessions: Bool = false
    var notifyWeeklyReview: Bool = false
    /// Minutes after midnight for the daily workout reminder.
    var workoutReminderMinutes: Int = 8 * 60
    var weighInReminderMinutes: Int = 7 * 60

    // Dashboard
    var dashboardCardsRaw: [String] = DashboardCard.allCases.map(\.rawValue)

    // Insights
    var disabledInsightCategories: [String] = []

    // Running goal
    var runningGoalLabel: String = ""
    var runningGoalDistanceMeters: Double = 3000
    var runningGoalSeconds: Double = 0

    // Custom catalogs (user-added options shown alongside built-ins)
    var customMuscleGroups: [String] = []
    var customEquipment: [String] = []
    var customRunTypes: [String] = []
    var customStretchAreas: [String] = []
    var customBodyMetrics: [String] = []
    var customActivityKinds: [String] = []

    // App state
    var onboardingComplete: Bool = false
    var seedDataVersion: Int = 0
    /// ID of the workout session currently in progress, for crash recovery.
    var activeWorkoutSessionID: UUID?

    init() {}

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kilograms }
        set { weightUnitRaw = newValue.rawValue }
    }

    var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRaw) ?? .kilometers }
        set { distanceUnitRaw = newValue.rawValue }
    }

    var lengthUnit: LengthUnit {
        get { LengthUnit(rawValue: lengthUnitRaw) ?? .centimeters }
        set { lengthUnitRaw = newValue.rawValue }
    }

    var appearance: AppAppearance {
        get { AppAppearance(rawValue: appearanceRaw) ?? .dark }
        set { appearanceRaw = newValue.rawValue }
    }

    var dashboardCards: [DashboardCard] {
        get { dashboardCardsRaw.compactMap(DashboardCard.init(rawValue:)) }
        set { dashboardCardsRaw = newValue.map(\.rawValue) }
    }

    func isInsightCategoryEnabled(_ category: InsightCategory) -> Bool {
        !disabledInsightCategories.contains(category.rawValue)
    }

    /// All muscle-group options: built-ins plus user-defined.
    var allMuscleGroupOptions: [String] {
        MuscleGroup.allCases.map(\.rawValue) + customMuscleGroups
    }

    var allEquipmentOptions: [String] {
        EquipmentType.allCases.map(\.rawValue) + customEquipment
    }

    /// Returns the settings singleton, creating it on first access.
    static func fetchOrCreate(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
