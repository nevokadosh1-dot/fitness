import SwiftUI
import SwiftData
import Charts

/// Running dashboard: personal bests, weekly volume, pace trend, goal progress.
struct RunningHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RunningSession.date, order: .reverse) private var runs: [RunningSession]
    @Query private var settingsList: [AppSettings]

    @State private var showNewRun = false
    @State private var bests: [PersonalRecord] = []

    private var settings: AppSettings? { settingsList.first }
    private var distanceUnit: DistanceUnit { settings?.distanceUnit ?? .kilometers }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if runs.isEmpty {
                    EmptyStateView(
                        systemImage: "figure.run",
                        title: "No runs logged",
                        message: "Log your first run — distance, time and type is all it takes.",
                        actionTitle: "Log a Run"
                    ) { showNewRun = true }
                } else {
                    bestsCard
                    goalCard
                    weeklyVolumeCard
                    paceTrendCard
                    predictionCard
                    recentRuns
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
        .navigationTitle("Running")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewRun = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("running.newRun")
            }
        }
        .sheet(isPresented: $showNewRun) {
            RunEditorView(run: nil)
        }
        .task { loadBests() }
    }

    // MARK: Personal bests

    @ViewBuilder
    private var bestsCard: some View {
        let timeBests = bests.filter { $0.kind == .fastestTime }
        if !timeBests.isEmpty {
            Card(accent: Theme.gold) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Personal Bests")
                    let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2)
                    LazyVGrid(columns: columns, spacing: Spacing.m) {
                        ForEach(timeBests.sorted(by: { $0.subject < $1.subject }), id: \.id) { record in
                            StatTile(label: record.subject, value: record.detail, tint: Theme.gold)
                        }
                    }
                }
            }
        }
    }

    // MARK: Goal

    @ViewBuilder
    private var goalCard: some View {
        if let settings, settings.runningGoalSeconds > 0 {
            let goalDistance = settings.runningGoalDistanceMeters
            let matching = runs.filter { abs($0.distanceMeters - goalDistance) <= goalDistance * 0.05 && $0.durationSeconds > 0 }
            Card(accent: Theme.running) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Goal")
                    let label = settings.runningGoalLabel.isEmpty
                        ? Formatting.distance(goalDistance, unit: distanceUnit)
                        : settings.runningGoalLabel
                    Text("\(label) in \(RunningMath.formatDuration(settings.runningGoalSeconds))")
                        .font(.forgeHeadline)
                        .foregroundStyle(Theme.textPrimary)
                    if let best = matching.min(by: { $0.durationSeconds < $1.durationSeconds }) {
                        let gap = best.durationSeconds - settings.runningGoalSeconds
                        if gap <= 0 {
                            Label("Goal achieved — best \(RunningMath.formatDuration(best.durationSeconds))", systemImage: "checkmark.seal.fill")
                                .font(.forgeSubheadline)
                                .foregroundStyle(Theme.accent)
                        } else {
                            Text("Current best \(RunningMath.formatDuration(best.durationSeconds)) — \(RunningMath.formatDuration(gap)) to go")
                                .font(.forgeSubheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        Text("No timed efforts at this distance yet.")
                            .font(.forgeSubheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: Weekly volume

    private var weeklyVolumeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Weekly Volume · 8 weeks")
                let weekly = weeklyVolume()
                if weekly.isEmpty {
                    Text("Not enough data yet").font(.forgeCaption).foregroundStyle(Theme.textTertiary)
                } else {
                    Chart(weekly, id: \.weekStart) { item in
                        BarMark(
                            x: .value("Week", item.weekStart, unit: .weekOfYear),
                            y: .value("Distance", UnitsConverter.displayDistance(meters: item.meters, unit: distanceUnit))
                        )
                        .foregroundStyle(Theme.running.gradient)
                        .cornerRadius(4)
                    }
                    .chartYAxisLabel(distanceUnit.suffix)
                    .frame(height: 150)
                }
            }
        }
    }

    private func weeklyVolume() -> [(weekStart: Date, meters: Double)] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .weekOfYear, value: -8, to: Date()) ?? Date()
        var byWeek: [Date: Double] = [:]
        for run in runs where run.date >= cutoff {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: run.date)?.start else { continue }
            byWeek[weekStart, default: 0] += run.distanceMeters
        }
        return byWeek.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    // MARK: Pace trend

    private var paceTrendCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Pace Trend · runs ≥ 1 km")
                let paced = runs
                    .filter { $0.distanceMeters >= 1000 }
                    .compactMap { run -> (Date, Double)? in
                        guard let pace = run.paceSecondsPerKm else { return nil }
                        return (run.date, pace / 60.0)
                    }
                    .sorted { $0.0 < $1.0 }
                    .suffix(30)
                if paced.count < 2 {
                    Text("Log a few more runs to see your pace trend.")
                        .font(.forgeCaption).foregroundStyle(Theme.textTertiary)
                } else {
                    Chart(Array(paced), id: \.0) { item in
                        LineMark(x: .value("Date", item.0), y: .value("Pace", item.1))
                            .foregroundStyle(Theme.running)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", item.0), y: .value("Pace", item.1))
                            .foregroundStyle(Theme.running)
                            .symbolSize(24)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel("min/km")
                    .frame(height: 150)
                    Text("Lower is faster. Mixed run types — expect spread.")
                        .font(.forgeOverline)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    // MARK: Prediction

    @ViewBuilder
    private var predictionCard: some View {
        let threeK = runs
            .filter { $0.matchedBenchmark == .threeK && $0.durationSeconds > 0 }
            .sorted { $0.date < $1.date }
        if threeK.count >= 3, let latest = threeK.last {
            let points = threeK.map { TrendPoint(date: $0.date, value: $0.durationSeconds) }
            if let fit = TrendAnalysis.linearFit(points), fit.slopePerDay < 0, fit.rSquared >= 0.3 {
                // Project 4 weeks ahead but never promise more than 3% improvement.
                let projected = max(latest.durationSeconds * 0.97,
                                    latest.durationSeconds + fit.slopePerDay * 28)
                Card(accent: Theme.running) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        SectionHeader("3 km Projection")
                        Text("≈ \(RunningMath.formatDuration(projected)) in ~4 weeks")
                            .font(.forgeStat)
                            .foregroundStyle(Theme.running)
                        Text("A conservative estimate from \(threeK.count) timed efforts — not a guarantee. Progress depends on training, recovery and conditions.")
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: Recent runs

    private var recentRuns: some View {
        VStack(spacing: Spacing.s) {
            SectionHeader("Recent Runs")
            ForEach(runs.prefix(15), id: \.id) { run in
                NavigationLink {
                    RunDetailView(run: run)
                } label: {
                    Card(accent: Theme.running) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(RunType.displayName(for: run.runTypeRaw))
                                    .font(.forgeHeadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(Formatting.mediumDate(run.date))
                                    .font(.forgeCaption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Formatting.distance(run.distanceMeters, unit: distanceUnit))
                                    .font(.forgeStat)
                                    .foregroundStyle(Theme.running)
                                Text(run.matchedBenchmark == .sprint100m
                                     ? RunningMath.formatSprintTime(run.durationSeconds)
                                     : "\(RunningMath.formatDuration(run.durationSeconds)) · \(run.paceSecondsPerKm.map { RunningMath.formatPace(secondsPerKm: $0, unit: distanceUnit) } ?? "—")")
                                    .font(.forgeCaption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadBests() {
        let descriptor = FetchDescriptor<PersonalRecord>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        bests = all.filter { $0.kind == .fastestTime || $0.kind == .bestPace || $0.kind == .longestRun }
    }
}
