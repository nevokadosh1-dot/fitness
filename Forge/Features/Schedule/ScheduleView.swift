import SwiftUI
import SwiftData

/// Weekly planning: view any week, complete/skip/move sessions for that week
/// only, add one-off activities, and manage schedule presets.
struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]
    @Query(sort: \WeeklySchedule.createdAt) private var schedules: [WeeklySchedule]

    @State private var weekOffset = 0
    @State private var week: ResolvedWeek?
    @State private var showPresets = false
    @State private var addingToDay: Date?

    private var settings: AppSettings? { settingsList.first }
    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    weekSelector
                    summaryCard
                    if let week {
                        ForEach(Array(week.days.enumerated()), id: \.offset) { _, day in
                            dayCard(day, week: week)
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Theme.background)
            .scrollIndicators(.hidden)
            .navigationTitle("Schedule")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showPresets = true
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                    }
                    .accessibilityLabel("Schedule presets")
                }
            }
            .task { refresh() }
            .onChange(of: weekOffset) { refresh() }
            .sheet(isPresented: $showPresets, onDismiss: { refresh() }) {
                SchedulePresetsView()
            }
            .sheet(item: $addingToDay, onDismiss: { refresh() }) { day in
                AddActivitySheet(day: day, weekStart: week?.weekStart ?? Date())
            }
        }
    }

    // MARK: Week selector

    private var weekSelector: some View {
        HStack {
            IconButton(systemImage: "chevron.left") { weekOffset -= 1 }
            Spacer()
            VStack(spacing: 2) {
                Text(weekTitle)
                    .font(.forgeHeadline)
                    .foregroundStyle(Theme.textPrimary)
                if weekOffset != 0 {
                    Button("Back to this week") { weekOffset = 0 }
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.accent)
                }
            }
            Spacer()
            IconButton(systemImage: "chevron.right") { weekOffset += 1 }
        }
    }

    private var weekTitle: String {
        guard let week else { return "This Week" }
        let end = calendar.date(byAdding: .day, value: 6, to: week.weekStart) ?? week.weekStart
        switch weekOffset {
        case 0: return "This Week"
        case 1: return "Next Week"
        case -1: return "Last Week"
        default: return "\(Formatting.shortDate(week.weekStart)) – \(Formatting.shortDate(end))"
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        if let week {
            Card {
                HStack(spacing: Spacing.l) {
                    ProgressRing(progress: week.completionRate, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(week.completedCount) of \(week.plannedCount) done")
                            .font(.forgeHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        let missed = week.activities.filter { $0.isMissed(now: Date(), calendar: calendar) }.count
                        Text(missed > 0 ? "\(missed) missed · \(week.skippedCount) skipped" : "\(week.skippedCount) skipped")
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    if schedules.filter({ !$0.name.isEmpty }).count > 0,
                       let active = schedules.first(where: \.isActive) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("PRESET").font(.forgeOverline).foregroundStyle(Theme.textTertiary)
                            Text(active.name)
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Day cards

    private func dayCard(_ day: Date, week: ResolvedWeek) -> some View {
        let activities = week.activities(on: day)
        let isToday = calendar.isDateInToday(day)
        return Card(accent: isToday ? Theme.accent : nil) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    Text(day.formatted(.dateTime.weekday(.wide)))
                        .font(.forgeHeadline)
                        .foregroundStyle(isToday ? Theme.accent : Theme.textPrimary)
                    Text(Formatting.shortDate(day))
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                    Button {
                        addingToDay = day
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add activity")
                }
                if activities.isEmpty {
                    Text("Free day")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    ForEach(activities) { activity in
                        activityRow(activity, week: week)
                    }
                }
            }
        }
    }

    private func activityRow(_ activity: ResolvedActivity, week: ResolvedWeek) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: statusIcon(activity))
                .foregroundStyle(statusColor(activity))
            VStack(alignment: .leading, spacing: 1) {
                Text(activity.title)
                    .font(.forgeSubheadline)
                    .foregroundStyle(activity.status == .skipped ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(activity.status == .skipped)
                HStack(spacing: Spacing.xs) {
                    Text(activity.kind.displayName)
                    if activity.isAdHoc { Text("· this week only") }
                    if activity.isMissed(now: Date(), calendar: calendar) {
                        Text("· missed").foregroundStyle(Theme.body)
                    }
                }
                .font(.forgeCaption)
                .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Menu {
                if activity.status != .completed && activity.kind != .rest {
                    Button("Mark Complete", systemImage: "checkmark.circle") {
                        ScheduleService.markComplete(activity, weekStart: week.weekStart, sessionID: nil, in: modelContext)
                        Haptics.success()
                        refresh()
                    }
                }
                if activity.status == .planned {
                    Button("Skip This Week", systemImage: "arrow.uturn.forward") {
                        ScheduleService.skip(activity, weekStart: week.weekStart, in: modelContext)
                        refresh()
                    }
                    Menu("Move to…") {
                        ForEach(Array(week.days.enumerated()), id: \.offset) { _, day in
                            Button(day.formatted(.dateTime.weekday(.wide))) {
                                let weekday = calendar.component(.weekday, from: day)
                                ScheduleService.move(activity, weekStart: week.weekStart, toWeekday: weekday, in: modelContext)
                                refresh()
                            }
                        }
                    }
                }
                if activity.overrideID != nil {
                    Button(activity.isAdHoc ? "Remove" : "Reset to Plan", systemImage: "arrow.counterclockwise", role: activity.isAdHoc ? .destructive : nil) {
                        ScheduleService.resetOverride(activity, weekStart: week.weekStart, in: modelContext)
                        refresh()
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func statusIcon(_ activity: ResolvedActivity) -> String {
        switch activity.status {
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "minus.circle"
        case .moved: return "arrow.right.circle"
        case .planned:
            return activity.isMissed(now: Date(), calendar: calendar)
                ? "exclamationmark.circle" : activity.kind.symbolName
        }
    }

    private func statusColor(_ activity: ResolvedActivity) -> Color {
        switch activity.status {
        case .completed: return Theme.accent
        case .skipped: return Theme.textTertiary
        case .moved: return Theme.running
        case .planned:
            return activity.isMissed(now: Date(), calendar: calendar)
                ? Theme.body : Theme.accent(for: activity.kind)
        }
    }

    private func refresh() {
        guard let settings else { return }
        let target = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
        week = ScheduleService.resolveWeek(containing: target, in: modelContext, settings: settings)
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

/// Adds a one-off activity to a specific day of the visible week.
struct AddActivitySheet: View {
    var day: Date
    var weekStart: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]
    @Query(sort: \FlexibilityRoutine.createdAt) private var routines: [FlexibilityRoutine]

    @State private var kind: ActivityKind = .strength
    @State private var title = ""
    @State private var templateID: UUID?
    @State private var routineID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    Picker("Type", selection: $kind) {
                        ForEach(ActivityKind.allCases) { Text($0.displayName).tag($0) }
                    }
                    TextField("Title", text: $title)
                    if kind == .strength {
                        Picker("Template", selection: $templateID) {
                            Text("None").tag(UUID?.none)
                            ForEach(templates.filter { !$0.isArchived }, id: \.id) { template in
                                Text(template.name).tag(UUID?.some(template.id))
                            }
                        }
                    }
                    if [.frontSplit, .middleSplit, .mobility, .recovery].contains(kind) {
                        Picker("Routine", selection: $routineID) {
                            Text("None").tag(UUID?.none)
                            ForEach(routines.filter { !$0.isArchived }, id: \.id) { routine in
                                Text(routine.name).tag(UUID?.some(routine.id))
                            }
                        }
                    }
                }
                Section {
                    Text("Added to \(day.formatted(.dateTime.weekday(.wide))) of this week only. The base plan is unchanged.")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let weekday = Calendar.current.component(.weekday, from: day)
                        let resolvedTitle = title.isEmpty ? defaultTitle : title
                        ScheduleService.addOneOff(kind: kind, title: resolvedTitle, weekday: weekday,
                                                  weekStart: weekStart, templateID: templateID,
                                                  routineID: routineID, in: modelContext)
                        Haptics.success()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var defaultTitle: String {
        if let templateID, let template = templates.first(where: { $0.id == templateID }) { return template.name }
        if let routineID, let routine = routines.first(where: { $0.id == routineID }) { return routine.name }
        return kind.displayName
    }
}
