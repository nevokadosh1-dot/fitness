import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var history: [(date: Date, exercise: WorkoutExercise)] = []

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                headerCard
                if !exercise.instructions.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            SectionHeader("Instructions")
                            Text(exercise.instructions)
                                .font(.forgeBody)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                if !exercise.personalNotes.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            SectionHeader("Notes")
                            Text(exercise.personalNotes)
                                .font(.forgeBody)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                historyCard
                actions
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            ExerciseEditorView(exercise: exercise)
        }
        .task { loadHistory() }
        .confirmationDialog("Delete this exercise?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Exercise", role: .destructive) {
                modelContext.delete(exercise)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Past workout history keeps its own copy of the name and stays intact.")
        }
    }

    private var headerCard: some View {
        Card(accent: Theme.accent) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let imageData = exercise.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                }
                HStack(spacing: Spacing.s) {
                    TagChip(text: exercise.primaryMuscleDisplayName, tint: Theme.accent, isSelected: true)
                    ForEach(exercise.secondaryMusclesRaw, id: \.self) { raw in
                        TagChip(text: MuscleGroup.displayName(for: raw))
                    }
                }
                HStack(spacing: Spacing.s) {
                    TagChip(text: exercise.category.displayName, tint: Theme.flexibility)
                    TagChip(text: exercise.equipmentDisplayName, tint: Theme.running)
                    if exercise.isUnilateral { TagChip(text: "Unilateral", tint: Theme.body) }
                }
                HStack(spacing: Spacing.l) {
                    if exercise.usesWeight {
                        StatTile(label: "Increment", value: Formatting.weight(exercise.defaultIncrementKg, unit: settings?.weightUnit ?? .kilograms))
                    }
                    StatTile(label: "Tracks", value: trackedFields)
                }
            }
        }
    }

    private var trackedFields: String {
        var parts: [String] = []
        if exercise.usesWeight { parts.append("Weight") }
        if exercise.usesReps { parts.append("Reps") }
        if exercise.usesDuration { parts.append("Time") }
        if exercise.usesDistance { parts.append("Distance") }
        if exercise.tracksRPE { parts.append("RPE") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var historyCard: some View {
        if !history.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SectionHeader("Recent Performances")
                    ForEach(Array(history.prefix(5).enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text(Formatting.mediumDate(entry.date))
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(summary(of: entry.exercise))
                                .font(.forgeSubheadline)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
            }
        }
    }

    private func summary(of workoutExercise: WorkoutExercise) -> String {
        let sets = workoutExercise.orderedSets.filter { $0.isCompleted && $0.setType.countsAsWorking }
        guard let best = sets.max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }) else { return "—" }
        let unit = settings?.weightUnit ?? .kilograms
        if let weight = best.weightKg, let reps = best.reps {
            return "\(sets.count) sets · top \(Formatting.weight(weight, unit: unit)) × \(reps)"
        }
        return "\(sets.count) sets"
    }

    private var actions: some View {
        VStack(spacing: Spacing.s) {
            Button {
                let copy = exercise.duplicated()
                modelContext.insert(copy)
                try? modelContext.save()
                Haptics.success()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                exercise.isArchived.toggle()
                try? modelContext.save()
            } label: {
                Label(exercise.isArchived ? "Restore from Archive" : "Archive", systemImage: "archivebox")
            }
            .buttonStyle(SecondaryButtonStyle())

            if !exercise.isBuiltIn {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Exercise", systemImage: "trash")
                }
                .buttonStyle(DangerButtonStyle())
            }
        }
    }

    private func loadHistory() {
        let sessions = StoreQueries.completedSessions(in: modelContext).suffix(60)
        var entries: [(Date, WorkoutExercise)] = []
        for session in sessions.reversed() {
            for workoutExercise in session.orderedExercises where workoutExercise.displayName == exercise.name {
                entries.append((session.completedAt ?? session.startedAt, workoutExercise))
            }
        }
        history = entries
    }
}
