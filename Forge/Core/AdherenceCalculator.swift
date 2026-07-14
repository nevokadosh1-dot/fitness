import Foundation

/// Schedule adherence math, resolved from planned activities and overrides.
enum AdherenceCalculator {

    /// Completion percentage for a resolved week (0…1).
    static func completionRate(planned: Int, completed: Int) -> Double {
        guard planned > 0 else { return 1 }
        return min(1, Double(completed) / Double(planned))
    }

    /// Average adherence across weeks, ignoring weeks with nothing planned.
    static func averageAdherence(weeks: [WeekAdherenceSnapshot]) -> Double? {
        let active = weeks.filter { $0.plannedCount > 0 }
        guard !active.isEmpty else { return nil }
        return active.reduce(0.0) { $0 + $1.completionRate } / Double(active.count)
    }

    /// Weeks (most recent first) where more than half the planned sessions were missed.
    static func poorWeeks(weeks: [WeekAdherenceSnapshot], threshold: Double = 0.5) -> [WeekAdherenceSnapshot] {
        weeks.filter { $0.plannedCount > 0 && $0.completionRate < threshold }
            .sorted { $0.weekStart > $1.weekStart }
    }

    /// The start of the week containing `date`, honoring the user's first weekday.
    static func weekStart(for date: Date, firstWeekday: Int, calendar baseCalendar: Calendar = .current) -> Date {
        var calendar = baseCalendar
        calendar.firstWeekday = firstWeekday
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        return calendar.startOfDay(for: interval?.start ?? date)
    }

    /// The seven days of the week starting at `weekStart`.
    static func weekDays(from weekStart: Date, calendar: Calendar = .current) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }
}
