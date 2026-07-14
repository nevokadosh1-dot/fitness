import Foundation
import SwiftData

/// Bridges the pure `InsightsEngine` to the store: builds the context from
/// live data, runs the rules, and upserts `Insight` rows by fingerprint so
/// dismissals persist until the underlying evidence changes.
enum InsightsService {

    static func buildContext(in context: ModelContext, settings: AppSettings) -> InsightContext {
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())

        var flexTargets: [String: Int] = [:]
        let routines = (try? context.fetch(FetchDescriptor<FlexibilityRoutine>())) ?? []
        for routine in routines where !routine.isArchived {
            flexTargets[routine.kindRaw, default: 0] += routine.targetSessionsPerWeek
        }

        let currentWeek = ScheduleService.resolveWeek(containing: Date(), in: context, settings: settings)
        var plannedPerDay = Array(repeating: 0, count: 7)
        for (index, day) in currentWeek.days.enumerated() {
            plannedPerDay[index] = currentWeek.activities(on: day).filter { $0.kind != .rest }.count
        }

        return InsightContext(
            now: Date(),
            calendar: .current,
            sessions: StoreQueries.completedSessions(in: context, since: ninetyDaysAgo).map(\.snapshot),
            runs: StoreQueries.runs(in: context, since: ninetyDaysAgo).map(\.snapshot),
            flexSessions: StoreQueries.flexSessions(in: context, since: ninetyDaysAgo).map(\.snapshot),
            flexMeasurements: StoreQueries.flexMeasurements(in: context).map(\.snapshot),
            adherenceWeeks: ScheduleService.recentAdherence(in: context, settings: settings),
            flexTargetsPerWeek: flexTargets,
            plannedPerDayThisWeek: plannedPerDay
        )
    }

    /// Regenerates insights and reconciles them with stored rows.
    @discardableResult
    static func refresh(in context: ModelContext, settings: AppSettings) -> [Insight] {
        let enabled = Set(InsightCategory.allCases.filter { settings.isInsightCategoryEnabled($0) })
        let engineContext = buildContext(in: context, settings: settings)
        let candidates = InsightsEngine().generate(context: engineContext, enabledCategories: enabled)

        let existing = (try? context.fetch(FetchDescriptor<Insight>())) ?? []
        let existingByFingerprint = Dictionary(grouping: existing, by: \.fingerprint)
        let candidateFingerprints = Set(candidates.map(\.fingerprint))

        // Remove insights whose evidence no longer holds.
        for insight in existing where !candidateFingerprints.contains(insight.fingerprint) {
            context.delete(insight)
        }

        // Insert new candidates; keep existing rows (and their dismissed flag).
        for candidate in candidates where existingByFingerprint[candidate.fingerprint] == nil {
            context.insert(Insight(
                fingerprint: candidate.fingerprint,
                category: candidate.category,
                title: candidate.title,
                body: candidate.body,
                evidence: candidate.evidence
            ))
        }
        try? context.save()

        let descriptor = FetchDescriptor<Insight>(sortBy: [SortDescriptor(\.generatedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
