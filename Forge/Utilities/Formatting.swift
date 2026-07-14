import Foundation

/// Shared numeric and date formatting helpers.
enum Formatting {

    /// "100", "102.5" — trims trailing zeros for weights and measurements.
    static func trimmed(_ value: Double, maxDecimals: Int = 2) -> String {
        guard value.isFinite else { return "—" }
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxDecimals
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// "1h 23m" style workout duration.
    static func workoutDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }

    /// Compact volume such as "12.4k kg".
    static func volume(_ kg: Double, unit: WeightUnit) -> String {
        let display = UnitsConverter.displayWeight(kg: kg, unit: unit)
        if display >= 10_000 {
            return String(format: "%.1fk %@", display / 1000, unit.suffix)
        }
        return "\(trimmed(display, maxDecimals: 0)) \(unit.suffix)"
    }

    static func weight(_ kg: Double, unit: WeightUnit) -> String {
        "\(trimmed(UnitsConverter.displayWeight(kg: kg, unit: unit), maxDecimals: 1)) \(unit.suffix)"
    }

    static func distance(_ meters: Double, unit: DistanceUnit) -> String {
        if meters < 1000 && unit == .kilometers {
            return "\(trimmed(meters, maxDecimals: 0)) m"
        }
        return "\(trimmed(UnitsConverter.displayDistance(meters: meters, unit: unit), maxDecimals: 2)) \(unit.suffix)"
    }

    static func length(_ cm: Double, unit: LengthUnit) -> String {
        "\(trimmed(UnitsConverter.displayLength(cm: cm, unit: unit), maxDecimals: 1)) \(unit.suffix)"
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func mediumDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func relativeDay(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return mediumDate(date)
    }
}
