import Foundation

/// A detected record, independent of persistence.
struct DetectedRecord: Equatable {
    var kind: PRKind
    var subject: String
    var detail: String
    var value: Double
    var date: Date
    var sessionID: UUID?
}

/// Recomputes every personal record from raw history. Called whenever sessions
/// are added, edited or deleted, so records always reflect current data.
enum PRDetector {

    // MARK: Strength

    static func strengthRecords(sessions: [SessionSnapshot]) -> [DetectedRecord] {
        var records: [DetectedRecord] = []
        var heaviest: [String: DetectedRecord] = [:]
        var bestE1RM: [String: DetectedRecord] = [:]
        var repsAtTopWeight: [String: DetectedRecord] = [:]
        var bestSessionVolume: DetectedRecord?

        for session in sessions.sorted(by: { $0.date < $1.date }) {
            let volume = session.totalVolumeKg
            if volume > 0, volume > (bestSessionVolume?.value ?? 0) {
                bestSessionVolume = DetectedRecord(
                    kind: .sessionVolume,
                    subject: session.name.isEmpty ? "Workout" : session.name,
                    detail: String(format: "%.0f kg total volume", volume),
                    value: volume,
                    date: session.date,
                    sessionID: session.id
                )
            }

            for exercise in session.exercises {
                let name = exercise.exerciseName
                guard !name.isEmpty else { continue }

                if let top = exercise.topWeightKg, top > (heaviest[name]?.value ?? 0) {
                    heaviest[name] = DetectedRecord(
                        kind: .heaviestWeight,
                        subject: name,
                        detail: String(format: "%.1f kg", top),
                        value: top,
                        date: session.date,
                        sessionID: session.id
                    )
                }

                if let e1rm = exercise.bestE1RM, e1rm > (bestE1RM[name]?.value ?? 0) {
                    bestE1RM[name] = DetectedRecord(
                        kind: .estimatedOneRM,
                        subject: name,
                        detail: String(format: "≈ %.1f kg estimated 1RM", e1rm),
                        value: e1rm,
                        date: session.date,
                        sessionID: session.id
                    )
                }

                // Most reps performed at the heaviest weight ever used for the exercise.
                if let top = exercise.topWeightKg {
                    let repsAtTop = exercise.sets
                        .filter { $0.isCompleted && $0.countsAsWorking && ($0.weightKg ?? 0) >= top - 0.01 }
                        .compactMap(\.reps)
                        .max() ?? 0
                    let existing = repsAtTopWeight[name]
                    let existingWeight = heaviest[name]?.value ?? 0
                    if repsAtTop > 0, top >= existingWeight - 0.01,
                       repsAtTop > Int(existing?.value ?? 0) || top > existingWeight {
                        repsAtTopWeight[name] = DetectedRecord(
                            kind: .repsAtWeight,
                            subject: name,
                            detail: "\(repsAtTop) reps @ \(Formatting.trimmed(top)) kg",
                            value: Double(repsAtTop),
                            date: session.date,
                            sessionID: session.id
                        )
                    }
                }
            }
        }

        records.append(contentsOf: heaviest.values)
        records.append(contentsOf: bestE1RM.values)
        records.append(contentsOf: repsAtTopWeight.values)
        if let bestSessionVolume { records.append(bestSessionVolume) }
        return records
    }

    // MARK: Running

    static func runningRecords(runs: [RunSnapshot]) -> [DetectedRecord] {
        var records: [DetectedRecord] = []

        for benchmark in BenchmarkDistance.allCases {
            let matching = runs.filter { $0.matchedBenchmark == benchmark && $0.durationSeconds > 0 }
            if let best = matching.min(by: { $0.durationSeconds < $1.durationSeconds }) {
                records.append(DetectedRecord(
                    kind: .fastestTime,
                    subject: benchmark.displayName,
                    detail: benchmark == .sprint100m
                        ? RunningMath.formatSprintTime(best.durationSeconds)
                        : RunningMath.formatDuration(best.durationSeconds),
                    value: best.durationSeconds,
                    date: best.date,
                    sessionID: best.id
                ))
            }
        }

        // Best pace over runs of at least 1 km (sprints excluded — pace there is misleading).
        let paced = runs.filter { $0.distanceMeters >= 1000 }
        if let bestPace = paced.compactMap({ run -> (RunSnapshot, Double)? in
            guard let pace = run.paceSecondsPerKm else { return nil }
            return (run, pace)
        }).min(by: { $0.1 < $1.1 }) {
            records.append(DetectedRecord(
                kind: .bestPace,
                subject: "Pace",
                detail: RunningMath.formatPace(secondsPerKm: bestPace.1),
                value: bestPace.1,
                date: bestPace.0.date,
                sessionID: bestPace.0.id
            ))
        }

        if let longest = runs.max(by: { $0.distanceMeters < $1.distanceMeters }), longest.distanceMeters > 0 {
            records.append(DetectedRecord(
                kind: .longestRun,
                subject: "Distance",
                detail: String(format: "%.2f km", longest.distanceMeters / 1000),
                value: longest.distanceMeters,
                date: longest.date,
                sessionID: longest.id
            ))
        }

        return records
    }

    // MARK: Flexibility

    static func flexibilityRecords(measurements: [FlexMeasurementSnapshot]) -> [DetectedRecord] {
        var records: [DetectedRecord] = []
        let kindByTarget: [SplitTarget: PRKind] = [
            .leftFront: .bestFrontSplitLeft,
            .rightFront: .bestFrontSplitRight,
            .middle: .bestMiddleSplit,
        ]

        for target in SplitTarget.allCases {
            // Compare within the same measurement method only; prefer the method
            // with the most data so the record reflects how the user measures.
            let forTarget = measurements.filter { $0.targetRaw == target.rawValue }
            guard !forTarget.isEmpty else { continue }
            let byMethod = Dictionary(grouping: forTarget, by: \.methodRaw)
            guard let preferred = byMethod.max(by: { $0.value.count < $1.value.count }),
                  let method = FlexibilityMetricMethod(rawValue: preferred.key) else { continue }
            let points = preferred.value

            let best = method.lowerIsBetter
                ? points.min(by: { $0.value < $1.value })
                : points.max(by: { $0.value < $1.value })
            if let best, let kind = kindByTarget[target] {
                records.append(DetectedRecord(
                    kind: kind,
                    subject: target.displayName,
                    detail: "\(Formatting.trimmed(best.value)) \(method.unitLabel) · \(method.displayName)",
                    value: best.value,
                    date: best.date,
                    sessionID: nil
                ))
            }
        }
        return records
    }

    // MARK: Consistency

    /// Longest run of consecutive weeks containing at least one training session.
    static func longestWeeklyStreak(sessionDates: [Date], calendar: Calendar = .current) -> DetectedRecord? {
        guard !sessionDates.isEmpty else { return nil }
        let weekStarts = Set(sessionDates.compactMap {
            calendar.dateInterval(of: .weekOfYear, for: $0)?.start
        })
        let sorted = weekStarts.sorted()
        guard let first = sorted.first else { return nil }

        var longest = 1
        var current = 1
        var bestEnd = first
        for index in 1..<sorted.count {
            let previous = sorted[index - 1]
            let expectedNext = calendar.date(byAdding: .weekOfYear, value: 1, to: previous)
            if let expectedNext, calendar.isDate(sorted[index], inSameDayAs: expectedNext) {
                current += 1
            } else {
                current = 1
            }
            if current > longest {
                longest = current
                bestEnd = sorted[index]
            }
        }

        return DetectedRecord(
            kind: .longestStreak,
            subject: "Training Streak",
            detail: "\(longest) consecutive week\(longest == 1 ? "" : "s")",
            value: Double(longest),
            date: bestEnd,
            sessionID: nil
        )
    }

    /// Full recompute across all data sources.
    static func allRecords(
        sessions: [SessionSnapshot],
        runs: [RunSnapshot],
        measurements: [FlexMeasurementSnapshot],
        flexSessions: [FlexSessionSnapshot],
        calendar: Calendar = .current
    ) -> [DetectedRecord] {
        var records = strengthRecords(sessions: sessions)
        records.append(contentsOf: runningRecords(runs: runs))
        records.append(contentsOf: flexibilityRecords(measurements: measurements))
        let allDates = sessions.map(\.date) + runs.map(\.date) + flexSessions.map(\.date)
        if let streak = longestWeeklyStreak(sessionDates: allDates, calendar: calendar) {
            records.append(streak)
        }
        return records
    }
}
