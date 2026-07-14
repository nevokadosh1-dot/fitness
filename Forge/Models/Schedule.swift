import Foundation
import SwiftData

/// A reusable weekly plan preset. Exactly one preset is active at a time.
@Model
final class WeeklySchedule {
    var id: UUID = UUID()
    var name: String = ""
    var isActive: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ScheduledActivity.schedule)
    var activities: [ScheduledActivity]? = []

    init(name: String, isActive: Bool = false) {
        self.id = UUID()
        self.name = name
        self.isActive = isActive
        self.createdAt = Date()
    }

    /// Activities for a Calendar weekday (1 = Sunday … 7 = Saturday), ordered.
    func activities(weekday: Int) -> [ScheduledActivity] {
        (activities ?? [])
            .filter { $0.weekday == weekday }
            .sorted { $0.sortIndex < $1.sortIndex }
    }
}

/// One planned session in a weekly preset. `weekday` uses Calendar numbering
/// (1 = Sunday … 7 = Saturday) regardless of the user's first-day-of-week setting.
@Model
final class ScheduledActivity {
    var id: UUID = UUID()
    var weekday: Int = 2
    var sortIndex: Int = 0
    var kindRaw: String = ActivityKind.strength.rawValue
    var title: String = ""
    var templateID: UUID?
    var routineID: UUID?
    var notes: String = ""

    var schedule: WeeklySchedule?

    init(weekday: Int, sortIndex: Int, kind: ActivityKind, title: String) {
        self.id = UUID()
        self.weekday = weekday
        self.sortIndex = sortIndex
        self.kindRaw = kind.rawValue
        self.title = title
    }

    var kind: ActivityKind {
        get { ActivityKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }
}

/// A week-specific change layered on top of the active preset: completing,
/// skipping or moving a planned activity, or adding a one-off activity.
/// The base preset itself is never mutated by these actions.
@Model
final class ScheduleOverride {
    var id: UUID = UUID()
    /// Start of the week (user's first weekday, midnight) this override applies to.
    var weekStart: Date = Date()
    /// The preset activity this override modifies; nil for one-off added activities.
    var activityID: UUID?
    var statusRaw: String = ScheduledStatus.planned.rawValue
    /// When status == .moved, the weekday the activity was moved to.
    var movedToWeekday: Int?
    /// Fields for one-off activities added just for this week.
    var kindRaw: String?
    var title: String?
    var templateID: UUID?
    var routineID: UUID?
    /// Logged session that satisfied this activity, if any.
    var completedSessionID: UUID?
    var completedAt: Date?

    init(weekStart: Date, activityID: UUID?) {
        self.id = UUID()
        self.weekStart = weekStart
        self.activityID = activityID
    }

    var status: ScheduledStatus {
        get { ScheduledStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }
}
