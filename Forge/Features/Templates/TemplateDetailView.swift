import SwiftUI
import SwiftData

struct TemplateDetailView: View {
    @Bindable var template: WorkoutTemplate

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var liveSession: WorkoutSession?

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                headerCard
                exercisesCard
                actions
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            TemplateEditorView(template: template)
        }
        .fullScreenCover(item: $liveSession) { session in
            LiveWorkoutView(session: session)
        }
        .confirmationDialog("Delete this template?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Template", role: .destructive) {
                modelContext.delete(template)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Workout history logged from this template is kept.")
        }
    }

    private var headerCard: some View {
        HeroCard(tint: Color(hex: template.colorHex)) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Image(systemName: template.iconName)
                        .font(.title2)
                        .foregroundStyle(Color(hex: template.colorHex))
                    Spacer()
                    if template.isArchived {
                        TagChip(text: "Archived", tint: Theme.neutral, isSelected: true)
                    }
                }
                if !template.details.isEmpty {
                    Text(template.details)
                        .font(.forgeSubheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: Spacing.l) {
                    StatTile(label: "Exercises", value: "\(template.exerciseCount)")
                    StatTile(label: "Sets", value: "\(template.totalPlannedSets)")
                    if let minutes = template.estimatedMinutes {
                        StatTile(label: "Est. Time", value: "~\(minutes)m")
                    }
                }
                Button {
                    guard let settings else { return }
                    Haptics.medium()
                    liveSession = WorkoutService.startSession(template: template, name: template.name, in: modelContext, settings: settings)
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Color(hex: template.colorHex)))
                .accessibilityIdentifier("template.start")
            }
        }
    }

    private var exercisesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeader("Exercises")
                if template.orderedExercises.isEmpty {
                    Text("No exercises yet — tap Edit to add some.")
                        .font(.forgeSubheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(template.orderedExercises, id: \.id) { templateExercise in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            if let group = templateExercise.supersetGroup {
                                TagChip(text: "SS\(group)", tint: Theme.gold, isSelected: true)
                            }
                            Text(templateExercise.displayName)
                                .font(.forgeHeadline)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(setSummary(templateExercise))
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if !templateExercise.notes.isEmpty {
                            Text(templateExercise.notes)
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    if templateExercise.id != template.orderedExercises.last?.id {
                        Divider().overlay(Theme.separator)
                    }
                }
            }
        }
    }

    private func setSummary(_ templateExercise: TemplateExercise) -> String {
        let sets = templateExercise.orderedPlannedSets
        let working = sets.filter { $0.setType != .warmup }
        let warmups = sets.count - working.count
        guard let first = working.first else { return "\(warmups) warm-up" }
        var text = "\(working.count) × \(first.repRangeText)"
        if let weight = first.targetWeightKg {
            text += " @ \(Formatting.weight(weight, unit: settings?.weightUnit ?? .kilograms))"
        } else if let rpe = first.targetRPE {
            text += " @ RPE \(Formatting.trimmed(rpe, maxDecimals: 1))"
        }
        if warmups > 0 { text = "\(warmups)W + " + text }
        return text
    }

    private var actions: some View {
        VStack(spacing: Spacing.s) {
            Button {
                duplicate()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                template.isArchived.toggle()
                try? modelContext.save()
            } label: {
                Label(template.isArchived ? "Restore from Archive" : "Archive", systemImage: "archivebox")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                showDeleteConfirm = true
            } label: {
                Label("Delete Template", systemImage: "trash")
            }
            .buttonStyle(DangerButtonStyle())
        }
    }

    private func duplicate() {
        let copy = WorkoutTemplate(name: template.name + " Copy", details: template.details,
                                   colorHex: template.colorHex, iconName: template.iconName)
        copy.estimatedMinutes = template.estimatedMinutes
        copy.notes = template.notes
        modelContext.insert(copy)
        for templateExercise in template.orderedExercises {
            let exerciseCopy = TemplateExercise(exercise: templateExercise.exercise, sortIndex: templateExercise.sortIndex)
            exerciseCopy.exerciseNameSnapshot = templateExercise.exerciseNameSnapshot
            exerciseCopy.notes = templateExercise.notes
            exerciseCopy.supersetGroup = templateExercise.supersetGroup
            exerciseCopy.alternativeExerciseIDs = templateExercise.alternativeExerciseIDs
            exerciseCopy.template = copy
            modelContext.insert(exerciseCopy)
            for planned in templateExercise.orderedPlannedSets {
                let setCopy = PlannedSet(sortIndex: planned.sortIndex, setType: planned.setType)
                setCopy.targetRepsMin = planned.targetRepsMin
                setCopy.targetRepsMax = planned.targetRepsMax
                setCopy.targetWeightKg = planned.targetWeightKg
                setCopy.targetRPE = planned.targetRPE
                setCopy.templateExercise = exerciseCopy
                modelContext.insert(setCopy)
            }
        }
        try? modelContext.save()
        Haptics.success()
    }
}
