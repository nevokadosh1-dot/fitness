import Foundation
import SwiftData

/// A planned activity resolved for a concrete week: base preset merged with
/// week-specific overrides and auto-matched against logged sessions.
struct ResolvedActivity: Identifiable, Equatable {
    var id: UUID
    /// The preset activity behind this entry; nil for one-off additions.
    var baseActivityID: UUID?
    var overrideID: UUID?
    var date: Date
    var weekday: Int
    var sortIndex: Int
    var kindRaw: String
    var title: String
    var templateID: UUID?
    var routineID: UUID?
    var status: ScheduledStatus
    /// Completed automatically because a matching session was logged that day.
    var autoCompleted: Bool = false
    var completedSessionID: UUID?
    var isAdHoc: Bool = false

    var kind: ActivityKind { ActivityKind(rawValue: kindRaw) ?? .custom }

    /// Planned but the day has passed.
    func isMissed(now: Date, calendar: Calendar) -> Bool {
        status == .planned && kind != .rest && calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }
}

struct ResolvedWeek: Equatable {
    var weekStart: Date
    var days: [Date]
    var activities: [ResolvedActivity]

    func activities(on date: Date, calendar: Calendar = .current) -> [ResolvedActivity] {
        activities
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Rest days are excluded from the completion math.
    var plannedCount: Int { activities.filter { $0.kind != .rest && $0.status != .skipped }.count }
    var completedCount: Int { activities.filter { $0.kind != .rest && $0.status == .completed }.count }
    var skippedCount: Int { activities.filter { $0.status == .skipped }.count }

    var completionRate: Double {
        AdherenceCalculator.completionRate(planned: plannedCount, completed: completedCount)
    }

    var adherenceSnapshot: WeekAdherenceSnapshot {
        WeekAdherenceSnapshot(
            weekStart: weekStart,
            plannedCount: plannedCount,
            completedCount: completedCount,
            skippedCount: skippedCount
        )
    }
}

enum ScheduleService {

    static func activeSchedule(in context: ModelContext) -> WeeklySchedule? {
        let descriptor = FetchDescriptor<WeeklySchedule>(sortBy: [SortDescriptor(\.createdAt)])
        let all = (try? context.fetch(descriptor)) ?? []
        return all.first(where: \.isActive) ?? all.first
    }

    static func overrides(in context: ModelContext, weekStart: Date) -> [ScheduleOverride] {
        let descriptor = FetchDescriptor<ScheduleOverride>(
            predicate: #Predicate { $0.weekStart == weekStart }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Resolves one week: preset activities + overrides + auto-completion from
    /// logged sessions. Pure given its inputs, so it is deterministic and testable.
    static func resolveWeek(
        weekStart: Date,
        schedule: WeeklySchedule?,
        overrides: [ScheduleOverride],
        loggedWorkouts: [WorkoutSession],
        loggedRuns: [RunningSession],
        loggedFlex: [FlexibilitySession],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> ResolvedWeek {
        let days = AdherenceCalculator.weekDays(from: weekStart, calendar: calendar)
        var resolved: [ResolvedActivity] = []
        let overridesByActivity = Dictionary(grouping: overrides.filter { $0.activityID != nil },
                                             by: { $0.activityID ?? UUID() })

        for activity in schedule?.activities ?? [] {
            let override = overridesByActivity[activity.id]?.first
            var weekday = activity.weekday
            var status = override?.status ?? .planned
            // A moved activity keeps its new day even after being completed.
            if let moved = override?.movedToWeekday {
                weekday = moved
            }
            if status == .moved {
                status = override?.completedAt != nil ? .completed : .planned
            }
            guard let date = days.first(where: { calendar.component(.weekday, from: $0) == weekday }) else { continue }
            resolved.append(ResolvedActivity(
                id: activity.id,
                baseActivityID: activity.id,
                overrideID: override?.id,
                date: date,
                weekday: weekday,
                sortIndex: activity.sortIndex,
                kindRaw: activity.kindRaw,
                title: activity.title,
                templateID: activity.templateID,
                routineID: activity.routineID,
                status: status,
                completedSessionID: override?.completedSessionID
            ))
        }

        // One-off activities added for this week only.
        for override in overrides where override.activityID == nil {
            guard let kindRaw = override.kindRaw,
                  let weekday = override.movedToWeekday,
                  let date = days.first(where: { calendar.component(.weekday, from: $0) == weekday })
            else { continue }
            resolved.append(ResolvedActivity(
                id: override.id,
                baseActivityID: nil,
                overrideID: override.id,
                date: date,
                weekday: weekday,
                sortIndex: 100,
                kindRaw: kindRaw,
                title: override.title ?? ActivityKind.displayName(for: kindRaw),
                templateID: override.templateID,
                routineID: override.routineID,
                status: override.status,
                completedSessionID: override.completedSessionID,
                isAdHoc: true
            ))
        }

        // Auto-complete planned activities when a matching session was logged that day.
        var usedWorkouts = Set<UUID>()
        var usedRuns = Set<UUID>()
        var usedFlex = Set<UUID>()

        for index in resolved.indices where resolved[index].status == .planned {
            let activity = resolved[index]
            switch activity.kind {
            case .strength:
                if let match = loggedWorkouts.first(where: { session in
                    !usedWorkouts.contains(session.id) && session.status == .completed &&
                    calendar.isDate(session.completedAt ?? session.startedAt, inSameDayAs: activity.date)
                }) {
                    usedWorkouts.insert(match.id)
                    resolved[index].status = .completed
                    resolved[index].autoCompleted = true
                    resolved[index].completedSessionID = match.id
                }
            case .running:
                if let match = loggedRuns.first(where: { run in
                    !usedRuns.contains(run.id) && calendar.isDate(run.date, inSameDayAs: activity.date)
                }) {
                    usedRuns.insert(match.id)
                    resolved[index].status = .completed
                    resolved[index].autoCompleted = true
                    resolved[index].completedSessionID = match.id
                }
            case .frontSplit, .middleSplit, .mobility, .recovery:
                if let match = loggedFlex.first(where: { flex in
                    !usedFlex.contains(flex.id) &&
                    calendar.isDate(flex.date, inSameDayAs: activity.date) &&
                    (flex.kindRaw == activity.kindRaw || activity.kind == .recovery)
                }) {
                    usedFlex.insert(match.id)
                    resolved[index].status = .completed
                    resolved[index].autoCompleted = true
                    resolved[index].completedSessionID = match.id
                }
            case .rest, .custom:
                break
            }
        }

        return ResolvedWeek(weekStart: weekStart, days: days, activities: resolved)
    }

    /// Convenience: resolve the week containing `date` from the live store.
    static func resolveWeek(containing date: Date, in context: ModelContext, settings: AppSettings) -> ResolvedWeek {
        let weekStart = AdherenceCalculator.weekStart(for: date, firstWeekday: settings.firstWeekday)
        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let workouts = StoreQueries.completedSessions(in: context, since: weekStart)
            .filter { ($0.completedAt ?? $0.startedAt) < weekEnd }
        let runs = StoreQueries.runs(in: context, since: weekStart).filter { $0.date < weekEnd }
        let flex = StoreQueries.flexSessions(in: context, since: weekStart).filter { $0.date < weekEnd }
        return resolveWeek(
            weekStart: weekStart,
            schedule: activeSchedule(in: context),
            overrides: overrides(in: context, weekStart: weekStart),
            loggedWorkouts: workouts,
            loggedRuns: runs,
            loggedFlex: flex
        )
    }

    /// Adherence snapshots for the trailing `weekCount` weeks (oldest first),
    /// used by the insights engine.
    static func recentAdherence(in context: ModelContext, settings: AppSettings, weekCount: Int = 6) -> [WeekAdherenceSnapshot] {
        let calendar = Calendar.current
        var snapshots: [WeekAdherenceSnapshot] = []
        for offset in stride(from: weekCount - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .weekOfYear, value: -offset, to: Date()) else { continue }
            let week = resolveWeek(containing: date, in: context, settings: settings)
            snapshots.append(week.adherenceSnapshot)
        }
        return snapshots
    }

    // MARK: Mutations (all operate on overrides; the base preset is untouched)

    private static func override(for activity: ResolvedActivity, weekStart: Date, in context: ModelContext) -> ScheduleOverride {
        if let overrideID = activity.overrideID,
           let existing = overrides(in: context, weekStart: weekStart).first(where: { $0.id == overrideID }) {
            return existing
        }
        let fresh = ScheduleOverride(weekStart: weekStart, activityID: activity.baseActivityID)
        context.insert(fresh)
        return fresh
    }

    static func markComplete(_ activity: ResolvedActivity, weekStart: Date, sessionID: UUID?, in context: ModelContext) {
        let target = override(for: activity, weekStart: weekStart, in: context)
        target.status = .completed
        target.completedAt = Date()
        target.completedSessionID = sessionID
        try? context.save()
    }

    static func skip(_ activity: ResolvedActivity, weekStart: Date, in context: ModelContext) {
        let target = override(for: activity, weekStart: weekStart, in: context)
        target.status = .skipped
        try? context.save()
    }

    static func move(_ activity: ResolvedActivity, weekStart: Date, toWeekday weekday: Int, in context: ModelContext) {
        let target = override(for: activity, weekStart: weekStart, in: context)
        if activity.isAdHoc {
            target.movedToWeekday = weekday
        } else {
            target.status = .moved
            target.movedToWeekday = weekday
        }
        try? context.save()
    }

    static func resetOverride(_ activity: ResolvedActivity, weekStart: Date, in context: ModelContext) {
        guard let overrideID = activity.overrideID,
              let existing = overrides(in: context, weekStart: weekStart).first(where: { $0.id == overrideID })
        else { return }
        context.delete(existing)
        try? context.save()
    }

    static func addOneOff(kind: ActivityKind, title: String, weekday: Int, weekStart: Date,
                          templateID: UUID? = nil, routineID: UUID? = nil, in context: ModelContext) {
        let override = ScheduleOverride(weekStart: weekStart, activityID: nil)
        override.kindRaw = kind.rawValue
        override.title = title
        override.movedToWeekday = weekday
        override.templateID = templateID
        override.routineID = routineID
        context.insert(override)
        try? context.save()
    }
}
