import Foundation

/// Strength calculations. All outputs are estimates for tracking trends,
/// clearly labeled as such in the UI — never medical or scientific claims.
enum StrengthMath {

    /// Estimated one-rep max using the Epley formula, cross-checked with
    /// Brzycki and averaged for a more conservative mid-range estimate.
    /// Returns nil-equivalent 0 guard behavior: callers pass reps >= 1.
    static func estimatedOneRM(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, reps > 0 else { return nil }
        if reps == 1 { return weightKg }
        // Formulas degrade badly past ~12 reps; cap to keep estimates sane.
        guard reps <= 12 else { return nil }
        let epley = weightKg * (1.0 + Double(reps) / 30.0)
        let brzycki = weightKg * 36.0 / (37.0 - Double(reps))
        return (epley + brzycki) / 2.0
    }

    /// Volume for a single set: weight × reps. Warm-ups are excluded upstream.
    static func setVolumeKg(weightKg: Double?, reps: Int?) -> Double {
        guard let weightKg, let reps, weightKg > 0, reps > 0 else { return 0 }
        return weightKg * Double(reps)
    }

    /// Tonnage across sets represented as (weight, reps, countsAsWorking, isCompleted).
    static func totalVolumeKg(sets: [SetSnapshot]) -> Double {
        sets.filter { $0.isCompleted && $0.countsAsWorking }
            .reduce(0) { $0 + setVolumeKg(weightKg: $1.weightKg, reps: $1.reps) }
    }

    /// Number of completed working-type sets (a proxy for training stress).
    static func hardSetCount(sets: [SetSnapshot]) -> Int {
        sets.filter { $0.isCompleted && $0.countsAsWorking }.count
    }

    static func averageRPE(sets: [SetSnapshot]) -> Double? {
        let rpes = sets.filter { $0.isCompleted && $0.countsAsWorking }.compactMap(\.rpe)
        guard !rpes.isEmpty else { return nil }
        return rpes.reduce(0, +) / Double(rpes.count)
    }

    /// Best (heaviest-equivalent) estimated 1RM across a collection of sets.
    static func bestEstimatedOneRM(sets: [SetSnapshot]) -> Double? {
        sets.filter { $0.isCompleted && $0.countsAsWorking }
            .compactMap { set -> Double? in
                guard let w = set.weightKg, let r = set.reps else { return nil }
                return estimatedOneRM(weightKg: w, reps: r)
            }
            .max()
    }
}
