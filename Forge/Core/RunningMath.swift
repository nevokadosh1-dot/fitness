import Foundation

/// Pace and running-performance calculations.
enum RunningMath {

    /// Average pace in seconds per kilometer. Nil for zero/negative distance.
    static func paceSecondsPerKm(distanceMeters: Double, durationSeconds: Double) -> Double? {
        guard distanceMeters > 0, durationSeconds > 0 else { return nil }
        return durationSeconds / (distanceMeters / 1000.0)
    }

    /// Average speed in km/h. Nil for zero/negative duration.
    static func speedKmPerHour(distanceMeters: Double, durationSeconds: Double) -> Double? {
        guard distanceMeters > 0, durationSeconds > 0 else { return nil }
        return (distanceMeters / 1000.0) / (durationSeconds / 3600.0)
    }

    /// Riegel formula: predicted time for a new distance from a known performance.
    /// Uses a conservative exponent (1.08 instead of the classic 1.06) so
    /// predictions slightly under-promise. Clearly labeled an estimate in the UI.
    static func predictTime(
        knownDistanceMeters: Double,
        knownTimeSeconds: Double,
        targetDistanceMeters: Double
    ) -> Double? {
        guard knownDistanceMeters > 0, knownTimeSeconds > 0, targetDistanceMeters > 0 else { return nil }
        let ratio = targetDistanceMeters / knownDistanceMeters
        return knownTimeSeconds * pow(ratio, 1.08)
    }

    /// Formats a duration like "23:41" or "1:02:05".
    static func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// Formats a duration with fractional seconds for sprints, e.g. "13.62 s".
    static func formatSprintTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        if seconds < 60 { return String(format: "%.2f s", seconds) }
        return formatDuration(seconds)
    }

    /// Formats pace like "4:52 /km" (or per mile when requested).
    static func formatPace(secondsPerKm: Double, unit: DistanceUnit = .kilometers) -> String {
        guard secondsPerKm.isFinite, secondsPerKm > 0 else { return "—" }
        let perUnit = unit == .kilometers ? secondsPerKm : secondsPerKm * 1.609344
        let total = Int(perUnit.rounded())
        return String(format: "%d:%02d /%@", total / 60, total % 60, unit.suffix)
    }
}
