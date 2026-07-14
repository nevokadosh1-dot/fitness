import Foundation

/// Everything the insights engine looks at, decoupled from persistence so the
/// rules are unit-testable and a hosted AI model could later consume the same
/// context without any storage changes.
struct InsightContext {
    var now: Date = Date()
    var calendar: Calendar = .current
    /// Completed strength sessions.
    var sessions: [SessionSnapshot] = []
    var runs: [RunSnapshot] = []
    var flexSessions: [FlexSessionSnapshot] = []
    var flexMeasurements: [FlexMeasurementSnapshot] = []
    /// Resolved adherence for recent weeks, most recent last.
    var adherenceWeeks: [WeekAdherenceSnapshot] = []
    /// Target flexibility sessions per week keyed by `FlexibilityKind` raw value.
    var flexTargetsPerWeek: [String: Int] = [:]
    /// Count of planned activities per day of the current week (0 = first day).
    var plannedPerDayThisWeek: [Int] = []
}

/// A suggestion produced by a rule. Fingerprints are stable for a given piece of
/// evidence so dismissing an insight keeps it hidden until the evidence changes.
struct InsightCandidate: Equatable {
    var category: InsightCategory
    var fingerprint: String
    var title: String
    var body: String
    var evidence: [String]
}

protocol InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate]
}

/// Runs every rule and returns candidates for enabled categories.
struct InsightsEngine {
    var rules: [InsightRule]

    init(rules: [InsightRule]? = nil) {
        self.rules = rules ?? [
            ProgressiveOverloadRule(),
            StalledExerciseRule(),
            HighRPERule(),
            DeloadRule(),
            MissedSessionsRule(),
            MuscleFrequencyRule(),
            RunningTrendRule(),
            FlexibilityConsistencyRule(),
            ScheduleConflictRule(),
            ProjectionRule(),
        ]
    }

    func generate(context: InsightContext, enabledCategories: Set<InsightCategory>) -> [InsightCandidate] {
        rules.flatMap { $0.evaluate(context) }
            .filter { enabledCategories.contains($0.category) }
    }
}

// MARK: - Shared helpers

enum InsightHelpers {
    /// Per-exercise performance history, ordered oldest → newest.
    static func exerciseHistory(sessions: [SessionSnapshot]) -> [String: [(date: Date, performance: ExercisePerformanceSnapshot)]] {
        var history: [String: [(date: Date, performance: ExercisePerformanceSnapshot)]] = [:]
        for session in sessions.sorted(by: { $0.date < $1.date }) {
            for exercise in session.exercises where !exercise.exerciseName.isEmpty {
                history[exercise.exerciseName, default: []].append((date: session.date, performance: exercise))
            }
        }
        return history
    }

    static func dateLabel(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - Strength rules

/// Suggests a small load increase when the last two exposures to an exercise
/// repeated the same top weight at a manageable RPE without losing reps.
struct ProgressiveOverloadRule: InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        var results: [InsightCandidate] = []
        for (name, entries) in InsightHelpers.exerciseHistory(sessions: context.sessions) {
            guard entries.count >= 2 else { continue }
            let recent = Array(entries.suffix(2))
            guard
                let weight0 = recent[0].performance.topWeightKg,
                let weight1 = recent[1].performance.topWeightKg,
                weight0 > 0, abs(weight0 - weight1) < 0.01
            else { continue }

            let reps0 = maxReps(recent[0].performance, atWeight: weight0)
            let reps1 = maxReps(recent[1].performance, atWeight: weight1)
            guard reps0 > 0, reps1 >= reps0 else { continue }

            let rpes = recent.compactMap { $0.performance.averageRPE }
            let manageable = rpes.isEmpty || (rpes.max() ?? 10) <= 8.0
            guard manageable else { continue }

            let rpeNote = rpes.isEmpty ? "no RPE logged" : String(format: "average RPE %.1f", rpes.max() ?? 0)
            results.append(InsightCandidate(
                category: .progressiveOverload,
                fingerprint: "overload|\(name)|\(Formatting.trimmed(weight1))|\(reps1)",
                title: "\(name): room to add load",
                body: "You handled \(Formatting.trimmed(weight1)) kg for \(reps1) reps in your last two sessions at a manageable effort. A small increase (one increment) may be appropriate. This is a suggestion based on your logs, not a guarantee.",
                evidence: recent.map { entry in
                    "\(InsightHelpers.dateLabel(entry.date)): top set \(Formatting.trimmed(entry.performance.topWeightKg ?? 0)) kg × \(maxReps(entry.performance, atWeight: entry.performance.topWeightKg ?? 0)) (\(rpeNote))"
                }
            ))
        }
        return results
    }

    private func maxReps(_ performance: ExercisePerformanceSnapshot, atWeight weight: Double) -> Int {
        performance.sets
            .filter { $0.isCompleted && $0.countsAsWorking && abs(($0.weightKg ?? 0) - weight) < 0.01 }
            .compactMap(\.reps)
            .max() ?? 0
    }
}

/// Flags exercises whose estimated 1RM has not improved across 3+ recent exposures.
struct StalledExerciseRule: InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        var results: [InsightCandidate] = []
        for (name, entries) in InsightHelpers.exerciseHistory(sessions: context.sessions) {
            let recent = Array(entries.suffix(4))
            guard recent.count >= 3 else { continue }
            let e1rms = recent.compactMap { $0.performance.bestE1RM }
            guard e1rms.count >= 3, let first = e1rms.first, let last = e1rms.last, first > 0 else { continue }
            // Stalled: no exposure in the window beat the first one by more than 1%.
            let best = e1rms.max() ?? first
            guard best <= first * 1.01, last <= first * 1.01 else { continue }

            results.append(InsightCandidate(
                category: .stalling,
                fingerprint: "stall|\(name)|\(recent.count)|\(Formatting.trimmed(first))",
                title: "\(name) looks stalled",
                body: "Estimated 1RM has been flat across your last \(recent.count) sessions of \(name). Options worth considering: a slight deload, a rep-range change, or swapping in a variation for a few weeks. Estimates only — judge how the sets actually feel.",
                evidence: zip(recent, e1rms).map { entry, e1rm in
                    "\(InsightHelpers.dateLabel(entry.date)): est. 1RM ≈ \(Formatting.trimmed(e1rm)) kg"
                }
            ))
        }
        return results
    }
}

/// Warns when average RPE is climbing while reps fall — a signal to hold load.
struct HighRPERule: InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        var results: [InsightCandidate] = []
        for (name, entries) in InsightHelpers.exerciseHistory(sessions: context.sessions) {
            let recent = Array(entries.suffix(3))
            guard recent.count >= 3 else { continue }
            let rpes = recent.compactMap { $0.performance.averageRPE }
            guard rpes.count == 3, rpes[2] > rpes[0] + 0.4, rpes[2] >= 8.5 else { continue }
            let reps = recent.map { entry in
                entry.performance.sets
                    .filter { $0.isCompleted && $0.countsAsWorking }
                    .compactMap(\.reps).reduce(0, +)
            }
            guard reps[2] <= reps[0] else { continue }

            results.append(InsightCandidate(
                category: .highFatigue,
                fingerprint: "rpe|\(name)|\(String(format: "%.1f", rpes[2]))",
                title: "\(name): effort rising, output falling",
                body: "Average RPE went from \(String(format: "%.1f", rpes[0])) to \(String(format: "%.1f", rpes[2])) over three sessions while total reps did not increase. Maintaining the current load may be more productive than adding weight right now.",
                evidence: zip(recent, zip(rpes, reps)).map { entry, pair in
                    "\(InsightHelpers.dateLabel(entry.date)): avg RPE \(String(format: "%.1f", pair.0)), \(pair.1) working reps"
                }
            ))
        }
        return results
    }
}

/// Suggests a lighter week after sustained near-maximal average session RPE.
struct DeloadRule: InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        let threeWeeksAgo = context.calendar.date(byAdding: .day, value: -21, to: context.now) ?? context.now
        let recent = context.sessions.filter { $0.date >= threeWeeksAgo }
        guard recent.count >= 5 else { return [] }
        let rpes = recent.compactMap(\.averageRPE)
        guard rpes.count >= 5 else { return [] }
        let average = rpes.reduce(0, +) / Double(rpes.count)
        guard average >= 8.5 else { return [] }

        return [InsightCandidate(
            category: .deload,
            fingerprint: "deload|\(String(format: "%.1f", average))|\(recent.count)",
            title: "Consider a lighter week",
            body: String(format: "Your average session RPE over the last three weeks is %.1f across %d workouts. Sustained near-maximal effort often benefits from a planned lighter week. Only you can judge how you actually feel — this is a pattern in your logs, not a diagnosis.", average, recent.count),
            evidence: recent.suffix(5).map {
                "\(InsightHelpers.dateLabel($0.date)): \($0.name.isEmpty ? "Workout" : $0.name), avg RPE \(String(format: "%.1f", $0.averageRPE ?? 0))"
            }
        )]
    }
}

// MARK: - Consistency rules

struct MissedSessionsRule: InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        let recentActive = context.adherenceWeeks.filter { $0.plannedCount > 0 }.suffix(2)
        guard recentActive.count == 2, recentActive.allSatisfy({ $0.completionRate < 0.6 }) else { return [] }
        let missed = recentActive.reduce(0) { $0 + ($1.plannedCount - $1.completedCount) }

        return [InsightCandidate(
            category: .consistency,
            fingerprint: "missed|\(recentActive.first?.weekStart.timeIntervalSince1970 ?? 0)|\(missed)",
            title: "Sessions are slipping",
            body: "You completed less than 60% of planned sessions in each of the last two active weeks (\(missed) sessions missed in total). A smaller plan you can hit consistently usually beats a bigger plan you can't.",
            evidence: recentActive.map {
                "Week of \(InsightHelpers.dateLabel($0.weekStart)): \($0.completedCount)/\($0.plannedCount) completed"
            }
        )]
    }
}

/// Compares 28-day training frequency across major muscle groups.
struct MuscleFrequencyRule: InsightRule {
    private static let majorGroups: [MuscleGroup] = [.chest, .back, .shoulders, .quads, .hamstrings, .glutes]

    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        let windowStart = context.calendar.date(byAdding: .day, value: -28, to: context.now) ?? context.now
        let recent = context.sessions.filter { $0.date >= windowStart }
        guard recent.count >= 4 else { return [] }

        var frequency: [String: Int] = [:]
        for session in recent {
            var groupsInSession = Set<String>()
            for exercise in session.exercises {
                groupsInSession.insert(exercise.primaryMuscleRaw)
                exercise.secondaryMusclesRaw.forEach { groupsInSession.insert($0) }
            }
            for group in groupsInSession { frequency[group, default: 0] += 1 }
        }

        let major = Self.majorGroups.map { ($0, frequency[$0.rawValue] ?? 0) }
        guard let most = major.max(by: { $0.1 < $1.1 }), most.1 >= 4 else { return [] }
        let neglected = major.filter { $0.1 <= 1 }
        guard !neglected.isEmpty else { return [] }

        return neglected.map { group, count in
            InsightCandidate(
                category: .muscleBalance,
                fingerprint: "freq|\(group.rawValue)|\(count)",
                title: "\(group.displayName) is trained rarely",
                body: "Over the last 4 weeks, \(group.displayName.lowercased()) appeared in \(count) session\(count == 1 ? "" : "s") while \(most.0.displayName.lowercased()) appeared in \(most.1). If that's intentional, ignore this — otherwise consider spreading the work more evenly.",
                evidence: [
                    "\(group.displayName): \(count) session\(count == 1 ? "" : "s") in 28 days",
                    "\(most.0.displayName): \(most.1) sessions in 28 days",
                ]
            )
        }
    }
}

// MARK: - Running rules

struct RunningTrendRule: InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        var results: [InsightCandidate] = []
        let windowStart = context.calendar.date(byAdding: .day, value: -90, to: context.now) ?? context.now

        for benchmark in [BenchmarkDistance.threeK, .fiveK, .oneK] {
            let efforts = context.runs
                .filter { $0.matchedBenchmark == benchmark && $0.date >= windowStart && $0.durationSeconds > 0 }
                .sorted { $0.date < $1.date }
            guard !efforts.isEmpty else { continue }

            if efforts.count < 3 {
                if efforts.count == 2, let last = efforts.last, let first = efforts.first,
                   last.durationSeconds < first.durationSeconds {
                    results.append(InsightCandidate(
                        category: .running,
                        fingerprint: "runtrend-early|\(benchmark.displayName)|\(Int(last.durationSeconds))",
                        title: "\(benchmark.displayName): early improvement",
                        body: "Your recent \(benchmark.displayName) trend is improving, but there is not enough data yet for a reliable trend — log a few more timed efforts.",
                        evidence: efforts.map { "\(InsightHelpers.dateLabel($0.date)): \(RunningMath.formatDuration($0.durationSeconds))" }
                    ))
                }
                continue
            }

            let points = efforts.map { TrendPoint(date: $0.date, value: $0.durationSeconds) }
            let direction = TrendAnalysis.direction(of: points, lowerIsBetter: true, meaningfulChangePerWeek: benchmark.meters * 0.002)
            let evidence = efforts.suffix(4).map { "\(InsightHelpers.dateLabel($0.date)): \(RunningMath.formatDuration($0.durationSeconds))" }

            switch direction {
            case .improving:
                results.append(InsightCandidate(
                    category: .running,
                    fingerprint: "runtrend|\(benchmark.displayName)|improving|\(efforts.count)",
                    title: "\(benchmark.displayName) is trending faster",
                    body: "Across \(efforts.count) timed efforts in the last 90 days, your \(benchmark.displayName) time is trending downward. Keep the current mix — no changes needed based on this data.",
                    evidence: evidence
                ))
            case .flat, .declining:
                results.append(InsightCandidate(
                    category: .running,
                    fingerprint: "runtrend|\(benchmark.displayName)|plateau|\(efforts.count)",
                    title: "\(benchmark.displayName) may be plateauing",
                    body: "Your \(benchmark.displayName) times have been flat or slightly slower across \(efforts.count) recent efforts. Plateaus are normal; varied paces (easy volume plus one quality session per week) often help. This is a pattern in your logs, not a prescription.",
                    evidence: evidence
                ))
            case nil:
                break
            }
        }
        return results
    }
}

// MARK: - Flexibility rules

struct FlexibilityConsistencyRule: InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        var results: [InsightCandidate] = []
        let weekStart = context.calendar.dateInterval(of: .weekOfYear, for: context.now)?.start ?? context.now
        // Evaluate only from mid-week so the user has had a chance to train.
        let dayOfWeek = context.calendar.dateComponents([.day], from: weekStart, to: context.now).day ?? 0
        guard dayOfWeek >= 4 else { return [] }

        for (kindRaw, target) in context.flexTargetsPerWeek where target > 0 {
            let done = context.flexSessions.filter { $0.kindRaw == kindRaw && $0.date >= weekStart }.count
            guard done < target else { continue }
            let kindName = FlexibilityKind(rawValue: kindRaw)?.displayName ?? kindRaw
            results.append(InsightCandidate(
                category: .flexibility,
                fingerprint: "flexweek|\(kindRaw)|\(weekStart.timeIntervalSince1970)|\(done)",
                title: "\(kindName): \(done) of \(target) sessions this week",
                body: "You've completed \(done) of \(target) planned \(kindName.lowercased()) sessions this week. Flexibility responds strongly to frequency — even a short session counts.",
                evidence: ["Week of \(InsightHelpers.dateLabel(weekStart)): \(done)/\(target) \(kindName) sessions logged"]
            ))
        }
        return results
    }
}

// MARK: - Schedule rules

struct ScheduleConflictRule: InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        guard let busiest = context.plannedPerDayThisWeek.enumerated().max(by: { $0.element < $1.element }),
              busiest.element >= 3 else { return [] }
        let dayIndex = busiest.offset
        let count = busiest.element
        return [InsightCandidate(
            category: .schedule,
            fingerprint: "conflict|\(dayIndex)|\(count)",
            title: "One day carries \(count) sessions",
            body: "One day of this week's plan has \(count) sessions stacked on it. If that day slips, most of the week slips with it — consider spreading sessions out.",
            evidence: ["Day \(dayIndex + 1) of the current week: \(count) planned sessions"]
        )]
    }
}

// MARK: - Projection rule

/// Conservative short-term projections for frequently trained lifts and the 3 km time.
struct ProjectionRule: InsightRule {
    func evaluate(_ context: InsightContext) -> [InsightCandidate] {
        var results: [InsightCandidate] = []
        let history = InsightHelpers.exerciseHistory(sessions: context.sessions)
        let frequent = history.sorted { $0.value.count > $1.value.count }.prefix(3)

        for (name, entries) in frequent {
            let points = entries.compactMap { entry -> TrendPoint? in
                guard let e1rm = entry.performance.bestE1RM else { return nil }
                return TrendPoint(date: entry.date, value: e1rm)
            }
            guard points.count >= 4, let fit = TrendAnalysis.linearFit(points), fit.rSquared >= 0.4,
                  fit.slopePerDay > 0, let last = points.last else { continue }
            // Project only 4 weeks out and cap the gain at 4% to stay conservative.
            let projected = min(last.value * 1.04, last.value + fit.slopePerDay * 28)
            guard projected > last.value + 0.5 else { continue }

            results.append(InsightCandidate(
                category: .projection,
                fingerprint: "proj|\(name)|\(Formatting.trimmed(projected))",
                title: "\(name): projected ≈ \(Formatting.trimmed(projected)) kg e1RM in ~4 weeks",
                body: "Based on a trend across \(points.count) sessions, your estimated 1RM could reach ≈ \(Formatting.trimmed(projected)) kg in about four weeks if current progress continues. This is a rough estimate, not a promise — progress is rarely linear.",
                evidence: points.suffix(4).map { "\(InsightHelpers.dateLabel($0.date)): est. 1RM ≈ \(Formatting.trimmed($0.value)) kg" }
            ))
        }
        return results
    }
}
