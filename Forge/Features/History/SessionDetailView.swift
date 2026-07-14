import SwiftUI
import SwiftData

/// A completed session in full detail, with edit / duplicate / delete / repeat.
struct SessionDetailView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showSaveAsTemplate = false
    @State private var templateName = ""
    @State private var liveSession: WorkoutSession?
    @State private var records: [PersonalRecord] = []

    private var settings: AppSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .kilograms }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                summaryCard
                recordsCard
                ForEach(session.orderedExercises, id: \.id) { exercise in
                    exerciseCard(exercise)
                }
                if !session.notes.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            SectionHeader("Notes")
                            Text(session.notes)
                                .font(.forgeBody)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                actions
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .navigationTitle(session.name.isEmpty ? "Workout" : session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            SessionEditView(session: session)
        }
        .fullScreenCover(item: $liveSession) { live in
            LiveWorkoutView(session: live)
        }
        .alert("Save as Template", isPresented: $showSaveAsTemplate) {
            TextField("Template name", text: $templateName)
            Button("Save") {
                let name = templateName.trimmingCharacters(in: .whitespaces)
                _ = WorkoutService.saveAsTemplate(session, name: name.isEmpty ? session.name : name, in: modelContext)
                Haptics.success()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Creates an editable template mirroring this session's exercises and sets.")
        }
        .confirmationDialog("Delete this workout?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Workout", role: .destructive) {
                WorkoutService.delete(session, in: modelContext)
                Haptics.warning()
                dismiss()
            }
        } message: {
            Text("Records will be recalculated. This cannot be undone.")
        }
        .task { loadRecords() }
    }

    private var summaryCard: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(Formatting.mediumDate(session.completedAt ?? session.startedAt))
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: Spacing.l) {
                    StatTile(label: "Duration", value: Formatting.workoutDuration(session.duration))
                    StatTile(label: "Volume", value: Formatting.volume(session.totalVolumeKg, unit: weightUnit), tint: Theme.accent)
                    StatTile(label: "Hard Sets", value: "\(session.hardSetCount)")
                }
                HStack(spacing: Spacing.l) {
                    if let rpe = session.averageRPE {
                        StatTile(label: "Avg RPE", value: String(format: "%.1f", rpe))
                    }
                    if let rating = session.rating {
                        StatTile(label: "Rating", value: String(repeating: "★", count: rating), tint: Theme.gold)
                    }
                    if let energy = session.energy {
                        StatTile(label: "Energy", value: "\(energy)/10")
                    }
                    if let soreness = session.soreness {
                        StatTile(label: "Soreness", value: "\(soreness)/10")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recordsCard: some View {
        if !records.isEmpty {
            Card(accent: Theme.gold) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Records set in this session")
                    ForEach(records, id: \.id) { record in
                        HStack {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.gold)
                            Text("\(record.subject): \(record.detail)")
                                .font(.forgeSubheadline)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private func exerciseCard(_ exercise: WorkoutExercise) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    Text(exercise.displayName)
                        .font(.forgeHeadline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(MuscleGroup.displayName(for: exercise.primaryMuscleSnapshot))
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
                ForEach(exercise.orderedSets, id: \.id) { set in
                    HStack {
                        Text(set.setType == .working ? "Set \(set.sortIndex + 1)" : set.setType.displayName)
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 76, alignment: .leading)
                        Text(setLine(set))
                            .font(.forgeSubheadline)
                            .foregroundStyle(set.isCompleted ? Theme.textPrimary : Theme.textTertiary)
                        Spacer()
                        if let rpe = set.rpe {
                            Text("RPE \(Formatting.trimmed(rpe, maxDecimals: 1))")
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if !set.isCompleted {
                            Text("skipped")
                                .font(.forgeOverline)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    private func setLine(_ set: CompletedSet) -> String {
        var parts: [String] = []
        if let weight = set.weightKg { parts.append(Formatting.weight(weight, unit: weightUnit)) }
        if let reps = set.reps { parts.append("× \(reps)") }
        if let duration = set.durationSeconds, duration > 0 {
            parts.append(RunningMath.formatDuration(duration))
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }

    private var actions: some View {
        VStack(spacing: Spacing.s) {
            Button {
                guard let settings else { return }
                Haptics.medium()
                liveSession = WorkoutService.startSession(copying: session, in: modelContext, settings: settings)
            } label: {
                Label("Repeat This Workout", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                templateName = session.name
                showSaveAsTemplate = true
            } label: {
                Label("Save as Template", systemImage: "square.grid.2x2")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                duplicateRecord()
            } label: {
                Label("Duplicate Entry", systemImage: "plus.square.on.square")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                showDeleteConfirm = true
            } label: {
                Label("Delete Workout", systemImage: "trash")
            }
            .buttonStyle(DangerButtonStyle())
        }
    }

    /// Copies the session as a second completed history entry (e.g. after
    /// logging on the wrong day and wanting an identical second record).
    private func duplicateRecord() {
        guard let settings else { return }
        let copy = WorkoutService.startSession(copying: session, in: modelContext, settings: settings)
        for exercise in copy.orderedExercises {
            let sourceExercise = session.orderedExercises.first { $0.sortIndex == exercise.sortIndex }
            for set in exercise.orderedSets {
                if let source = sourceExercise?.orderedSets.first(where: { $0.sortIndex == set.sortIndex }) {
                    set.reps = source.reps
                    set.rpe = source.rpe
                    set.isCompleted = source.isCompleted
                    set.completedAt = source.completedAt
                }
            }
        }
        copy.startedAt = session.startedAt
        copy.notes = session.notes
        WorkoutService.finish(copy, in: modelContext, settings: settings, completedAt: session.completedAt ?? session.startedAt)
        Haptics.success()
    }

    private func loadRecords() {
        let sessionID: UUID? = session.id
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate { $0.sessionID == sessionID }
        )
        records = (try? modelContext.fetch(descriptor)) ?? []
    }
}

/// Edit a past session: date, notes and every set value. Records are
/// recalculated on save so history edits propagate correctly.
struct SessionEditView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var completedAt = Date()
    @State private var loaded = false

    private var settings: AppSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .kilograms }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            SectionHeader("Session")
                            TextField("Name", text: $session.name)
                                .font(.forgeHeadline)
                                .foregroundStyle(Theme.textPrimary)
                            DatePicker("Completed", selection: $completedAt)
                                .tint(Theme.accent)
                                .font(.forgeSubheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    ForEach(session.orderedExercises, id: \.id) { exercise in
                        LiveExerciseCard(
                            exercise: exercise,
                            weightUnit: weightUnit,
                            showRPE: settings?.showRPE ?? true,
                            previous: nil,
                            best: nil,
                            onReplace: {},
                            onMoveUp: {},
                            onMoveDown: {},
                            onRemove: {
                                modelContext.delete(exercise)
                                try? modelContext.save()
                            }
                        )
                    }
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            SectionHeader("Notes")
                            TextField("Notes", text: $session.notes, axis: .vertical)
                                .font(.forgeBody)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2...6)
                        }
                    }
                }
                .padding(Spacing.l)
            }
            .background(Theme.background)
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        session.completedAt = completedAt
                        try? modelContext.save()
                        PRService.recompute(in: modelContext)
                        Haptics.success()
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                completedAt = session.completedAt ?? session.startedAt
            }
        }
        .preferredColorScheme(.dark)
    }
}
