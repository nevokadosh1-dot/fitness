import SwiftUI
import SwiftData

/// Manage weekly-schedule presets: create, activate, edit, duplicate, delete.
struct SchedulePresetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeeklySchedule.createdAt) private var schedules: [WeeklySchedule]

    @State private var editingSchedule: WeeklySchedule?
    @State private var scheduleToDelete: WeeklySchedule?

    var body: some View {
        NavigationStack {
            List {
                ForEach(schedules, id: \.id) { schedule in
                    Button {
                        editingSchedule = schedule
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(schedule.name)
                                    .font(.forgeHeadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(schedule.activities?.count ?? 0) planned sessions")
                                    .font(.forgeCaption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if schedule.isActive {
                                TagChip(text: "Active", tint: Theme.accent, isSelected: true)
                            }
                        }
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !schedule.isActive {
                            Button("Activate") { activate(schedule) }.tint(Theme.accent)
                            Button("Delete", role: .destructive) { scheduleToDelete = schedule }
                        }
                        Button("Duplicate") { duplicate(schedule) }.tint(Theme.running)
                    }
                }

                Button {
                    let fresh = WeeklySchedule(name: "New Plan", isActive: schedules.isEmpty)
                    modelContext.insert(fresh)
                    try? modelContext.save()
                    editingSchedule = fresh
                } label: {
                    Label("New Preset", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Schedule Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingSchedule) { schedule in
                SchedulePresetEditorView(schedule: schedule)
            }
            .confirmationDialog("Delete this preset?", isPresented: Binding(
                get: { scheduleToDelete != nil },
                set: { if !$0 { scheduleToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete Preset", role: .destructive) {
                    if let scheduleToDelete {
                        modelContext.delete(scheduleToDelete)
                        try? modelContext.save()
                    }
                    scheduleToDelete = nil
                }
            } message: {
                Text("Week history and logged sessions are kept.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func activate(_ schedule: WeeklySchedule) {
        for other in schedules { other.isActive = false }
        schedule.isActive = true
        try? modelContext.save()
        Haptics.success()
    }

    private func duplicate(_ schedule: WeeklySchedule) {
        let copy = WeeklySchedule(name: schedule.name + " Copy")
        modelContext.insert(copy)
        for activity in schedule.activities ?? [] {
            let activityCopy = ScheduledActivity(weekday: activity.weekday, sortIndex: activity.sortIndex,
                                                 kind: activity.kind, title: activity.title)
            activityCopy.templateID = activity.templateID
            activityCopy.routineID = activity.routineID
            activityCopy.notes = activity.notes
            activityCopy.schedule = copy
            modelContext.insert(activityCopy)
        }
        try? modelContext.save()
        Haptics.success()
    }
}

/// Edit one preset: name and per-weekday planned activities.
struct SchedulePresetEditorView: View {
    @Bindable var schedule: WeeklySchedule

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]
    @Query(sort: \FlexibilityRoutine.createdAt) private var routines: [FlexibilityRoutine]

    private var settings: AppSettings? { settingsList.first }

    /// Weekdays ordered by the user's first-day preference.
    private var orderedWeekdays: [Int] {
        let first = settings?.firstWeekday ?? 2
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset") {
                    TextField("Name", text: $schedule.name)
                    Toggle("Active preset", isOn: Binding(
                        get: { schedule.isActive },
                        set: { newValue in
                            if newValue { deactivateOthers() }
                            schedule.isActive = newValue
                        }
                    ))
                    .tint(Theme.accent)
                }
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    daySection(weekday)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(schedule.name.isEmpty ? "Preset" : schedule.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func daySection(_ weekday: Int) -> some View {
        Section(weekdayName(weekday)) {
            ForEach(schedule.activities(weekday: weekday), id: \.id) { activity in
                NavigationLink {
                    ScheduledActivityEditorView(activity: activity, templates: templates, routines: routines)
                } label: {
                    HStack {
                        Image(systemName: activity.kind.symbolName)
                            .foregroundStyle(Theme.accent(for: activity.kind))
                        Text(activity.title)
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
            .onDelete { offsets in
                let items = schedule.activities(weekday: weekday)
                for offset in offsets { modelContext.delete(items[offset]) }
            }
            Button {
                let nextIndex = ((schedule.activities ?? []).map(\.sortIndex).max() ?? -1) + 1
                let activity = ScheduledActivity(weekday: weekday, sortIndex: nextIndex, kind: .strength, title: "Strength")
                activity.schedule = schedule
                modelContext.insert(activity)
            } label: {
                Label("Add", systemImage: "plus.circle")
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        return symbols[(weekday - 1 + 7) % 7]
    }

    private func deactivateOthers() {
        let all = (try? modelContext.fetch(FetchDescriptor<WeeklySchedule>())) ?? []
        for other in all where other.id != schedule.id { other.isActive = false }
    }
}

/// Edit one planned activity in a preset.
struct ScheduledActivityEditorView: View {
    @Bindable var activity: ScheduledActivity
    var templates: [WorkoutTemplate]
    var routines: [FlexibilityRoutine]

    var body: some View {
        Form {
            Section("Activity") {
                Picker("Type", selection: Binding(get: { activity.kind }, set: { newKind in
                    activity.kind = newKind
                    if activity.title.isEmpty { activity.title = newKind.displayName }
                })) {
                    ForEach(ActivityKind.allCases) { Text($0.displayName).tag($0) }
                }
                TextField("Title", text: $activity.title)
            }
            if activity.kind == .strength {
                Section("Linked Template") {
                    Picker("Template", selection: Binding(
                        get: { activity.templateID },
                        set: { newID in
                            activity.templateID = newID
                            if let newID, let template = templates.first(where: { $0.id == newID }) {
                                activity.title = template.name
                            }
                        }
                    )) {
                        Text("None").tag(UUID?.none)
                        ForEach(templates.filter { !$0.isArchived }, id: \.id) { template in
                            Text(template.name).tag(UUID?.some(template.id))
                        }
                    }
                }
            }
            if [.frontSplit, .middleSplit, .mobility, .recovery].contains(activity.kind) {
                Section("Linked Routine") {
                    Picker("Routine", selection: Binding(
                        get: { activity.routineID },
                        set: { newID in
                            activity.routineID = newID
                            if let newID, let routine = routines.first(where: { $0.id == newID }) {
                                activity.title = routine.name
                            }
                        }
                    )) {
                        Text("None").tag(UUID?.none)
                        ForEach(routines.filter { !$0.isArchived }, id: \.id) { routine in
                            Text(routine.name).tag(UUID?.some(routine.id))
                        }
                    }
                }
            }
            Section("Notes") {
                TextField("Notes", text: $activity.notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(activity.title.isEmpty ? "Activity" : activity.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
