import SwiftUI
import SwiftData
import Charts

/// Trend analytics with selectable time ranges and per-area sections.
/// All values are computed from stored data; estimates are labeled as such.
struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    @State private var rangeDays = 90
    @State private var area: Area = .strength
    @State private var selectedExercise: String?
    @State private var selectedMuscle: String?

    @State private var sessions: [SessionSnapshot] = []
    @State private var runs: [RunSnapshot] = []
    @State private var flexSessions: [FlexSessionSnapshot] = []
    @State private var flexMeasurements: [FlexMeasurementSnapshot] = []
    @State private var adherence: [WeekAdherenceSnapshot] = []

    enum Area: String, CaseIterable, Identifiable {
        case strength = "Strength"
        case running = "Running"
        case flexibility = "Flexibility"
        case consistency = "Consistency"
        var id: String { rawValue }
    }

    private var settings: AppSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .kilograms }
    private var distanceUnit: DistanceUnit { settings?.distanceUnit ?? .kilometers }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                Picker("Range", selection: $rangeDays) {
                    Text("30d").tag(30)
                    Text("90d").tag(90)
                    Text("6m").tag(180)
                    Text("1y").tag(365)
                }
                .pickerStyle(.segmented)

                Picker("Area", selection: $area) {
                    ForEach(Area.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch area {
                case .strength: strengthSection
                case .running: runningSection
                case .flexibility: flexibilitySection
                case .consistency: consistencySection
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task { refresh() }
        .onChange(of: rangeDays) { refresh() }
    }

    // MARK: Strength

    private var exerciseNames: [String] {
        var counts: [String: Int] = [:]
        for session in sessions {
            for exercise in session.exercises {
                counts[exercise.exerciseName, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    @ViewBuilder
    private var strengthSection: some View {
        if sessions.isEmpty {
            emptyCard("No strength sessions in this range yet.")
        } else {
            weeklyVolumeChart
            e1rmChart
            muscleVolumeChart
            rpeTrendChart
        }
    }

    private var weeklyVolumeChart: some View {
        Card(accent: Theme.accent) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Weekly Training Volume")
                let weekly = weeklyBuckets(dates: sessions.map(\.date), values: sessions.map(\.totalVolumeKg))
                if weekly.count < 2 {
                    notEnoughData
                } else {
                    Chart(weekly, id: \.week) { item in
                        BarMark(
                            x: .value("Week", item.week, unit: .weekOfYear),
                            y: .value("Volume", UnitsConverter.displayWeight(kg: item.value, unit: weightUnit))
                        )
                        .foregroundStyle(Theme.accent.gradient)
                        .cornerRadius(4)
                    }
                    .chartYAxisLabel(weightUnit.suffix)
                    .frame(height: 160)
                }
            }
        }
    }

    private var e1rmChart: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Estimated 1RM · per exercise")
                exerciseFilterChips
                if let name = selectedExercise ?? exerciseNames.first {
                    let points: [TrendPoint] = sessions.compactMap { session in
                        guard let exercise = session.exercises.first(where: { $0.exerciseName == name }),
                              let e1rm = exercise.bestE1RM else { return nil }
                        return TrendPoint(date: session.date, value: e1rm)
                    }
                    if points.count < 2 {
                        notEnoughData
                    } else {
                        Chart(points, id: \.date) { point in
                            LineMark(x: .value("Date", point.date),
                                     y: .value("e1RM", UnitsConverter.displayWeight(kg: point.value, unit: weightUnit)))
                                .foregroundStyle(Theme.accent)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", point.date),
                                      y: .value("e1RM", UnitsConverter.displayWeight(kg: point.value, unit: weightUnit)))
                                .foregroundStyle(Theme.accent)
                                .symbolSize(24)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartYAxisLabel(weightUnit.suffix)
                        .frame(height: 160)
                        Text("Estimated from weight × reps (Epley/Brzycki average, capped at 12 reps). An estimate, not a tested max.")
                            .font(.forgeOverline)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
    }

    private var exerciseFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(exerciseNames.prefix(10), id: \.self) { name in
                    Button {
                        selectedExercise = name
                        Haptics.light()
                    } label: {
                        TagChip(text: name, tint: Theme.accent,
                                isSelected: name == (selectedExercise ?? exerciseNames.first))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var muscleVolumeChart: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Hard Sets per Muscle · weekly average")
                let rows = muscleVolumeRows()
                if rows.isEmpty {
                    notEnoughData
                } else {
                    Chart(rows, id: \.muscle) { row in
                        BarMark(x: .value("Sets", row.avg), y: .value("Muscle", row.muscle))
                            .foregroundStyle(Theme.accent.gradient)
                            .cornerRadius(4)
                    }
                    .chartXAxisLabel("hard sets / week")
                    .frame(height: CGFloat(rows.count) * 32 + 30)
                }
            }
        }
    }

    private var rpeTrendChart: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Average Session RPE")
                let points = sessions.compactMap { session -> TrendPoint? in
                    guard let rpe = session.averageRPE else { return nil }
                    return TrendPoint(date: session.date, value: rpe)
                }
                if points.count < 2 {
                    notEnoughData
                } else {
                    Chart(points, id: \.date) { point in
                        LineMark(x: .value("Date", point.date), y: .value("RPE", point.value))
                            .foregroundStyle(Theme.body)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", point.date), y: .value("RPE", point.value))
                            .foregroundStyle(Theme.body)
                            .symbolSize(20)
                    }
                    .chartYScale(domain: 5...10)
                    .frame(height: 140)
                }
            }
        }
    }

    // MARK: Running

    @ViewBuilder
    private var runningSection: some View {
        if runs.isEmpty {
            emptyCard("No runs in this range yet.")
        } else {
            Card(accent: Theme.running) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Weekly Distance")
                    let weekly = weeklyBuckets(dates: runs.map(\.date), values: runs.map(\.distanceMeters))
                    if weekly.count < 2 {
                        notEnoughData
                    } else {
                        Chart(weekly, id: \.week) { item in
                            BarMark(
                                x: .value("Week", item.week, unit: .weekOfYear),
                                y: .value("Distance", UnitsConverter.displayDistance(meters: item.value, unit: distanceUnit))
                            )
                            .foregroundStyle(Theme.running.gradient)
                            .cornerRadius(4)
                        }
                        .chartYAxisLabel(distanceUnit.suffix)
                        .frame(height: 160)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Pace · runs ≥ 1 km")
                    let points = runs
                        .filter { $0.distanceMeters >= 1000 }
                        .compactMap { run -> TrendPoint? in
                            guard let pace = run.paceSecondsPerKm else { return nil }
                            return TrendPoint(date: run.date, value: pace / 60)
                        }
                    if points.count < 2 {
                        notEnoughData
                    } else {
                        Chart(points, id: \.date) { point in
                            LineMark(x: .value("Date", point.date), y: .value("min/km", point.value))
                                .foregroundStyle(Theme.running)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", point.date), y: .value("min/km", point.value))
                                .foregroundStyle(Theme.running)
                                .symbolSize(20)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartYAxisLabel("min/km · lower is faster")
                        .frame(height: 150)
                    }
                }
            }

            benchmarkChart(.threeK)
        }
    }

    private func benchmarkChart(_ benchmark: BenchmarkDistance) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("\(benchmark.displayName) Times")
                let efforts = runs
                    .filter { $0.matchedBenchmark == benchmark && $0.durationSeconds > 0 }
                    .sorted { $0.date < $1.date }
                if efforts.count < 2 {
                    Text(efforts.count == 1
                         ? "One timed effort logged — one more starts the trend."
                         : "No \(benchmark.displayName) efforts in this range.")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 50)
                } else {
                    Chart(efforts, id: \.id) { run in
                        LineMark(x: .value("Date", run.date), y: .value("Minutes", run.durationSeconds / 60))
                            .foregroundStyle(Theme.running)
                        PointMark(x: .value("Date", run.date), y: .value("Minutes", run.durationSeconds / 60))
                            .foregroundStyle(Theme.running)
                            .symbolSize(28)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel("minutes · lower is faster")
                    .frame(height: 150)
                }
            }
        }
    }

    // MARK: Flexibility

    @ViewBuilder
    private var flexibilitySection: some View {
        if flexSessions.isEmpty && flexMeasurements.isEmpty {
            emptyCard("No flexibility sessions or measurements in this range yet.")
        } else {
            Card(accent: Theme.flexibility) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Sessions per Week")
                    let weekly = weeklyBuckets(dates: flexSessions.map(\.date), values: flexSessions.map { _ in 1.0 })
                    if weekly.count < 2 {
                        notEnoughData
                    } else {
                        Chart(weekly, id: \.week) { item in
                            BarMark(x: .value("Week", item.week, unit: .weekOfYear),
                                    y: .value("Sessions", item.value))
                                .foregroundStyle(Theme.flexibility.gradient)
                                .cornerRadius(4)
                        }
                        .frame(height: 140)
                    }
                }
            }

            ForEach(SplitTarget.allCases) { target in
                splitMeasurementChart(target)
            }
        }
    }

    @ViewBuilder
    private func splitMeasurementChart(_ target: SplitTarget) -> some View {
        let forTarget = flexMeasurements.filter { $0.targetRaw == target.rawValue }
        let byMethod = Dictionary(grouping: forTarget, by: \.methodRaw)
        if let preferred = byMethod.max(by: { $0.value.count < $1.value.count }),
           let method = FlexibilityMetricMethod(rawValue: preferred.key), preferred.value.count >= 2 {
            let points = preferred.value
            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader(target.displayName)
                    Chart(points.sorted { $0.date < $1.date }, id: \.date) { point in
                        LineMark(x: .value("Date", point.date), y: .value(method.unitLabel, point.value))
                            .foregroundStyle(Theme.flexibility)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", point.date), y: .value(method.unitLabel, point.value))
                            .foregroundStyle(Theme.flexibility)
                            .symbolSize(22)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel("\(method.unitLabel)\(method.lowerIsBetter ? " · lower is better" : "")")
                    .frame(height: 140)
                }
            }
        }
    }

    // MARK: Consistency

    @ViewBuilder
    private var consistencySection: some View {
        Card(accent: Theme.gold) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Schedule Adherence · weekly")
                let active = adherence.filter { $0.plannedCount > 0 }
                if active.count < 2 {
                    notEnoughData
                } else {
                    Chart(active, id: \.weekStart) { week in
                        BarMark(x: .value("Week", week.weekStart, unit: .weekOfYear),
                                y: .value("Completion", week.completionRate * 100))
                            .foregroundStyle(Theme.gold.gradient)
                            .cornerRadius(4)
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxisLabel("%")
                    .frame(height: 150)
                    if let average = AdherenceCalculator.averageAdherence(weeks: active) {
                        Text("Average adherence: \(Formatting.percent(average))")
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }

        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("All Activity · sessions per week")
                let allDates = sessions.map(\.date) + runs.map(\.date) + flexSessions.map(\.date)
                let weekly = weeklyBuckets(dates: allDates, values: allDates.map { _ in 1.0 })
                if weekly.count < 2 {
                    notEnoughData
                } else {
                    Chart(weekly, id: \.week) { item in
                        BarMark(x: .value("Week", item.week, unit: .weekOfYear),
                                y: .value("Sessions", item.value))
                            .foregroundStyle(Theme.textSecondary.gradient)
                            .cornerRadius(4)
                    }
                    .frame(height: 140)
                }
            }
        }
    }

    // MARK: Helpers

    private func muscleVolumeRows() -> [(muscle: String, avg: Double)] {
        let weeks = max(1.0, Double(rangeDays) / 7.0)
        var perMuscle: [String: Int] = [:]
        for session in sessions {
            for exercise in session.exercises {
                perMuscle[exercise.primaryMuscleRaw, default: 0] += exercise.hardSets
            }
        }
        return Array(
            perMuscle
                .map { (muscle: MuscleGroup.displayName(for: $0.key), avg: Double($0.value) / weeks) }
                .sorted { $0.avg > $1.avg }
                .prefix(8)
        )
    }

    private var notEnoughData: some View {
        Text("Not enough data in this range yet.")
            .font(.forgeCaption)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 60)
    }

    private func emptyCard(_ message: String) -> some View {
        Card {
            EmptyStateView(systemImage: "chart.bar", title: "Nothing to chart", message: message)
        }
    }

    private func weeklyBuckets(dates: [Date], values: [Double]) -> [(week: Date, value: Double)] {
        let calendar = Calendar.current
        var buckets: [Date: Double] = [:]
        for (date, value) in zip(dates, values) {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { continue }
            buckets[week, default: 0] += value
        }
        return buckets.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    private func refresh() {
        guard let settings else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date())
        sessions = StoreQueries.completedSessions(in: modelContext, since: cutoff).map(\.snapshot)
        runs = StoreQueries.runs(in: modelContext, since: cutoff).map(\.snapshot)
        flexSessions = StoreQueries.flexSessions(in: modelContext, since: cutoff).map(\.snapshot)
        flexMeasurements = StoreQueries.flexMeasurements(in: modelContext).map(\.snapshot)
            .filter { cutoff == nil || $0.date >= cutoff! }
        adherence = ScheduleService.recentAdherence(in: modelContext, settings: settings,
                                                    weekCount: max(4, rangeDays / 7))
    }
}
