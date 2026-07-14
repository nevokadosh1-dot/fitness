import SwiftUI
import SwiftData

/// The daily dashboard: today's plan, week status, trends and suggestions.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    @State private var week: ResolvedWeek?
    @State private var activeSession: WorkoutSession?
    @State private var lastWorkout: WorkoutSession?
    @State private var recentPRs: [PersonalRecord] = []
    @State private var bodyWeightPoints: [TrendPoint] = []
    @State private var lastRun: RunningSession?
    @State private var splitProgress: [SplitTarget: FlexibilityMeasurement] = [:]
    @State private var topInsight: Insight?

    @State private var liveSession: WorkoutSession?
    @State private var flexRoutineToStart: FlexibilityRoutine?
    @State private var showRunEntry = false

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    header

                    if let activeSession {
                        activeWorkoutBanner(activeSession)
                    }

                    ForEach(settings?.dashboardCards ?? DashboardCard.allCases) { card in
                        cardView(for: card)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Theme.background)
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .task { refresh() }
            .refreshable { refresh() }
            .fullScreenCover(item: $liveSession, onDismiss: { refresh() }) { session in
                LiveWorkoutView(session: session)
            }
            .fullScreenCover(item: $flexRoutineToStart, onDismiss: { refresh() }) { routine in
                LiveFlexibilityView(routine: routine)
            }
            .sheet(isPresented: $showRunEntry, onDismiss: { refresh() }) {
                RunEditorView(run: nil)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.forgeCaption)
                .foregroundStyle(Theme.textSecondary)
            Text(greeting)
                .font(.forgeHero)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.s)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning Session"
        case 12..<17: return "Afternoon Session"
        default: return "Evening Session"
        }
    }

    // MARK: Card routing

    @ViewBuilder
    private func cardView(for card: DashboardCard) -> some View {
        switch card {
        case .todayPlan: todayPlanCard
        case .weekStatus: weekStatusCard
        case .lastWorkout: lastWorkoutCard
        case .bodyWeight: bodyWeightCard
        case .recentPRs: recentPRsCard
        case .running: runningCard
        case .frontSplit: splitCard(title: "Front Split", targets: [.leftFront, .rightFront])
        case .middleSplit: splitCard(title: "Middle Split", targets: [.middle])
        case .readiness: readinessCard
        case .suggestion: suggestionCard
        }
    }

    // MARK: Active workout

    private func activeWorkoutBanner(_ session: WorkoutSession) -> some View {
        Button {
            liveSession = session
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: session.status == .paused ? "pause.circle.fill" : "bolt.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.black)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.status == .paused ? "Workout paused" : "Workout in progress")
                        .font(.forgeHeadline)
                        .foregroundStyle(Color.black)
                    Text("\(session.name.isEmpty ? "Workout" : session.name) · \(Formatting.workoutDuration(session.duration))")
                        .font(.forgeCaption)
                        .foregroundStyle(Color.black.opacity(0.7))
                }
                Spacer()
                Text("Resume")
                    .font(.forgeCaption)
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.15)))
            }
            .padding(Spacing.l)
            .background(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.resumeWorkout")
    }

    // MARK: Today's plan

    @ViewBuilder
    private var todayPlanCard: some View {
        let todayActivities = week?.activities(on: Date()) ?? []
        HeroCard(tint: todayActivities.first.map { Theme.accent(for: $0.kind) } ?? Theme.accent) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeader("Today's Plan")
                if todayActivities.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("Nothing scheduled")
                            .font(.forgeHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("A free day. Start something anyway, or enjoy the rest — consistency is built over weeks, not single days.")
                            .font(.forgeSubheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Button("Start Empty Workout") { startEmptyWorkout() }
                            .buttonStyle(SecondaryButtonStyle())
                            .padding(.top, Spacing.xs)
                    }
                } else {
                    ForEach(todayActivities) { activity in
                        todayActivityRow(activity)
                        if activity.id != todayActivities.last?.id {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func todayActivityRow(_ activity: ResolvedActivity) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: activity.kind.symbolName)
                .font(.title3)
                .foregroundStyle(Theme.accent(for: activity.kind))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(activity.title)
                    .font(.forgeHeadline)
                    .foregroundStyle(Theme.textPrimary)
                Text(statusLine(for: activity))
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if activity.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            } else if activity.kind == .rest {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(Theme.neutral)
            } else {
                Button("Start") { start(activity) }
                    .buttonStyle(PillButtonStyle(tint: Theme.accent(for: activity.kind), filled: true))
                    .accessibilityIdentifier("today.startActivity")
            }
        }
    }

    private func statusLine(for activity: ResolvedActivity) -> String {
        switch activity.status {
        case .completed: return activity.autoCompleted ? "Completed — logged today" : "Marked complete"
        case .skipped: return "Skipped this week"
        case .moved: return "Moved"
        case .planned:
            if activity.kind == .rest { return "Recovery matters as much as training" }
            return activity.kind.displayName
        }
    }

    // MARK: Week status

    @ViewBuilder
    private var weekStatusCard: some View {
        if let week {
            Card {
                HStack(spacing: Spacing.l) {
                    ProgressRing(progress: week.completionRate, size: 64)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("This Week")
                            .font(.forgeHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(week.completedCount) of \(week.plannedCount) sessions complete")
                            .font(.forgeSubheadline)
                            .foregroundStyle(Theme.textSecondary)
                        let missed = week.activities.filter { $0.isMissed(now: Date(), calendar: .current) }.count
                        if missed > 0 {
                            Text("\(missed) missed — reschedule from the Schedule tab")
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.body)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: Last workout

    @ViewBuilder
    private var lastWorkoutCard: some View {
        if let lastWorkout {
            NavigationLink {
                SessionDetailView(session: lastWorkout)
            } label: {
                Card(accent: Theme.accent) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        SectionHeader("Last Workout")
                        Text(lastWorkout.name.isEmpty ? "Workout" : lastWorkout.name)
                            .font(.forgeHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        HStack(spacing: Spacing.l) {
                            StatTile(label: "When", value: Formatting.relativeDay(lastWorkout.completedAt ?? lastWorkout.startedAt))
                            StatTile(label: "Volume", value: Formatting.volume(lastWorkout.totalVolumeKg, unit: settings?.weightUnit ?? .kilograms))
                            StatTile(label: "Sets", value: "\(lastWorkout.hardSetCount)")
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Body weight

    @ViewBuilder
    private var bodyWeightCard: some View {
        if !bodyWeightPoints.isEmpty {
            Card(accent: Theme.body) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Body Weight · 30 days")
                    HStack(alignment: .lastTextBaseline) {
                        if let latest = bodyWeightPoints.last {
                            Text(Formatting.weight(latest.value, unit: settings?.weightUnit ?? .kilograms))
                                .font(.forgeStat)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer()
                        weightDeltaLabel
                    }
                    SparklineChart(points: bodyWeightPoints, tint: Theme.body)
                        .frame(height: 56)
                }
            }
        }
    }

    @ViewBuilder
    private var weightDeltaLabel: some View {
        if bodyWeightPoints.count >= 2,
           let first = bodyWeightPoints.first, let last = bodyWeightPoints.last {
            let delta = last.value - first.value
            let unit = settings?.weightUnit ?? .kilograms
            Text("\(delta >= 0 ? "+" : "")\(Formatting.trimmed(UnitsConverter.displayWeight(kg: delta, unit: unit), maxDecimals: 1)) \(unit.suffix)")
                .font(.forgeCaption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Recent PRs

    @ViewBuilder
    private var recentPRsCard: some View {
        if !recentPRs.isEmpty {
            Card(accent: Theme.gold) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Recent Records")
                    ForEach(recentPRs.prefix(3), id: \.id) { record in
                        HStack {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.gold)
                            Text(record.subject)
                                .font(.forgeSubheadline)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(record.detail)
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Running

    @ViewBuilder
    private var runningCard: some View {
        if let lastRun {
            Card(accent: Theme.running) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Running")
                    HStack(spacing: Spacing.l) {
                        StatTile(label: "Last Run", value: Formatting.distance(lastRun.distanceMeters, unit: settings?.distanceUnit ?? .kilometers), tint: Theme.running)
                        StatTile(label: "Pace", value: lastRun.paceSecondsPerKm.map { RunningMath.formatPace(secondsPerKm: $0, unit: settings?.distanceUnit ?? .kilometers) } ?? "—")
                        StatTile(label: "When", value: Formatting.relativeDay(lastRun.date))
                    }
                    if let goal = runningGoalText {
                        Text(goal)
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    private var runningGoalText: String? {
        guard let settings, settings.runningGoalSeconds > 0 else { return nil }
        let label = settings.runningGoalLabel.isEmpty
            ? Formatting.distance(settings.runningGoalDistanceMeters, unit: settings.distanceUnit)
            : settings.runningGoalLabel
        return "Goal: \(label) in \(RunningMath.formatDuration(settings.runningGoalSeconds))"
    }

    // MARK: Splits

    @ViewBuilder
    private func splitCard(title: String, targets: [SplitTarget]) -> some View {
        let entries = targets.compactMap { target in splitProgress[target].map { (target, $0) } }
        if !entries.isEmpty {
            Card(accent: Theme.flexibility) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader(title)
                    HStack(spacing: Spacing.l) {
                        ForEach(entries, id: \.0) { entry in
                            StatTile(
                                label: entry.0 == .middle ? "Latest" : (entry.0 == .leftFront ? "Left" : "Right"),
                                value: Formatting.trimmed(entry.1.value),
                                unit: entry.1.method.unitLabel,
                                tint: Theme.flexibility
                            )
                        }
                    }
                    if let latest = entries.first?.1 {
                        Text("\(latest.method.displayName) · \(Formatting.relativeDay(latest.date))")
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: Readiness

    @ViewBuilder
    private var readinessCard: some View {
        if let lastWorkout, let energy = lastWorkout.energy ?? lastWorkout.readiness {
            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Recovery Check")
                    HStack(spacing: Spacing.l) {
                        StatTile(label: "Energy", value: "\(energy)/10")
                        if let soreness = lastWorkout.soreness {
                            StatTile(label: "Soreness", value: "\(soreness)/10")
                        }
                        if let rpe = lastWorkout.averageRPE {
                            StatTile(label: "Avg RPE", value: String(format: "%.1f", rpe))
                        }
                    }
                    Text("From your last finished workout — how you actually feel today matters more.")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    // MARK: Suggestion

    @ViewBuilder
    private var suggestionCard: some View {
        if let topInsight {
            NavigationLink {
                InsightsView()
            } label: {
                Card(accent: Theme.accent) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        SectionHeader("Suggested Focus")
                        HStack(spacing: Spacing.m) {
                            Image(systemName: topInsight.category.symbolName)
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topInsight.title)
                                    .font(.forgeHeadline)
                                    .foregroundStyle(Theme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text("Tap for the reasoning and more insights")
                                    .font(.forgeCaption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Actions & data

    private func start(_ activity: ResolvedActivity) {
        guard let settings else { return }
        Haptics.medium()
        switch activity.kind {
        case .strength:
            let template = findTemplate(for: activity)
            let session = WorkoutService.startSession(template: template, name: activity.title, in: modelContext, settings: settings)
            liveSession = session
        case .frontSplit, .middleSplit, .mobility, .recovery:
            flexRoutineToStart = findRoutine(for: activity)
        case .running:
            showRunEntry = true
        case .rest, .custom:
            ScheduleService.markComplete(activity, weekStart: week?.weekStart ?? Date(), sessionID: nil, in: modelContext)
            refresh()
        }
    }

    private func startEmptyWorkout() {
        guard let settings else { return }
        Haptics.medium()
        liveSession = WorkoutService.startSession(template: nil, name: "Workout", in: modelContext, settings: settings)
    }

    private func findTemplate(for activity: ResolvedActivity) -> WorkoutTemplate? {
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        if let id = activity.templateID, let match = templates.first(where: { $0.id == id }) { return match }
        return templates.first { $0.name == activity.title && !$0.isArchived }
    }

    private func findRoutine(for activity: ResolvedActivity) -> FlexibilityRoutine? {
        let routines = (try? modelContext.fetch(FetchDescriptor<FlexibilityRoutine>())) ?? []
        if let id = activity.routineID, let match = routines.first(where: { $0.id == id }) { return match }
        if let match = routines.first(where: { $0.name == activity.title && !$0.isArchived }) { return match }
        return routines.first { $0.kindRaw == activity.kindRaw && !$0.isArchived }
    }

    private func refresh() {
        guard let settings else { return }
        week = ScheduleService.resolveWeek(containing: Date(), in: modelContext, settings: settings)
        activeSession = StoreQueries.activeSession(in: modelContext)
        lastWorkout = StoreQueries.completedSessions(in: modelContext).last
        recentPRs = PRService.recent(in: modelContext, days: 30)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        bodyWeightPoints = StoreQueries
            .bodyEntries(in: modelContext, metricRaw: BodyMetric.bodyWeight.rawValue, since: thirtyDaysAgo)
            .map { TrendPoint(date: $0.date, value: $0.value) }
        lastRun = StoreQueries.runs(in: modelContext).last

        var latestByTarget: [SplitTarget: FlexibilityMeasurement] = [:]
        for measurement in StoreQueries.flexMeasurements(in: modelContext) {
            latestByTarget[measurement.target] = measurement
        }
        splitProgress = latestByTarget

        topInsight = InsightsService.refresh(in: modelContext, settings: settings).first { !$0.isDismissed }
    }
}

/// Minimal line chart used inside dashboard cards.
struct SparklineChart: View {
    var points: [TrendPoint]
    var tint: Color

    var body: some View {
        GeometryReader { geometry in
            let sorted = points.sorted { $0.date < $1.date }
            if sorted.count >= 2,
               let minValue = sorted.map(\.value).min(),
               let maxValue = sorted.map(\.value).max(),
               let firstDate = sorted.first?.date,
               let lastDate = sorted.last?.date,
               lastDate > firstDate {
                let range = max(maxValue - minValue, 0.001)
                let span = lastDate.timeIntervalSince(firstDate)
                let path = Path { path in
                    for (index, point) in sorted.enumerated() {
                        let x = geometry.size.width * (point.date.timeIntervalSince(firstDate) / span)
                        let y = geometry.size.height * (1 - (point.value - minValue) / range)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                path.stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else {
                Text("Not enough data yet")
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
