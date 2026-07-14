import Foundation

/// A single (date, value) observation used for trend fitting.
struct TrendPoint: Equatable {
    var date: Date
    var value: Double
}

/// Simple linear-regression based trend analysis with deliberately
/// conservative interpretation thresholds.
enum TrendAnalysis {

    struct LinearFit: Equatable {
        /// Change in value per day.
        var slopePerDay: Double
        var intercept: Double
        /// Coefficient of determination (0…1); how well the line fits.
        var rSquared: Double
        var pointCount: Int

        func projected(daysFromFirstPoint days: Double) -> Double {
            intercept + slopePerDay * days
        }
    }

    /// Least-squares fit over (daysSinceFirst, value). Nil with < 3 points —
    /// two points always fit perfectly and would produce false confidence.
    static func linearFit(_ points: [TrendPoint]) -> LinearFit? {
        guard points.count >= 3, let first = points.map(\.date).min() else { return nil }
        let xs = points.map { $0.date.timeIntervalSince(first) / 86_400.0 }
        let ys = points.map(\.value)
        let n = Double(points.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }
        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-9 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        let meanY = sumY / n
        let ssTotal = ys.reduce(0) { $0 + ($1 - meanY) * ($1 - meanY) }
        let ssResidual = zip(xs, ys).reduce(0) { acc, pair in
            let predicted = intercept + slope * pair.0
            return acc + (pair.1 - predicted) * (pair.1 - predicted)
        }
        let rSquared = ssTotal > 1e-9 ? max(0, 1 - ssResidual / ssTotal) : 0
        return LinearFit(slopePerDay: slope, intercept: intercept, rSquared: rSquared, pointCount: points.count)
    }

    enum Direction { case improving, flat, declining }

    /// Classifies a trend. `lowerIsBetter` flips the sign (e.g. run times, floor distance).
    /// `meaningfulChangePerWeek` guards against calling noise a trend.
    static func direction(
        of points: [TrendPoint],
        lowerIsBetter: Bool,
        meaningfulChangePerWeek: Double
    ) -> Direction? {
        guard let fit = linearFit(points) else { return nil }
        let weeklyChange = fit.slopePerDay * 7
        guard abs(weeklyChange) >= meaningfulChangePerWeek, fit.rSquared >= 0.2 else { return .flat }
        let improving = lowerIsBetter ? weeklyChange < 0 : weeklyChange > 0
        return improving ? .improving : .declining
    }

    /// Rolling average over a trailing window, aligned to each point.
    static func rollingAverage(_ points: [TrendPoint], windowDays: Int) -> [TrendPoint] {
        guard !points.isEmpty, windowDays > 0 else { return [] }
        let sorted = points.sorted { $0.date < $1.date }
        return sorted.map { point in
            let windowStart = point.date.addingTimeInterval(-Double(windowDays) * 86_400)
            let window = sorted.filter { $0.date > windowStart && $0.date <= point.date }
            let avg = window.reduce(0.0) { $0 + $1.value } / Double(window.count)
            return TrendPoint(date: point.date, value: avg)
        }
    }
}
