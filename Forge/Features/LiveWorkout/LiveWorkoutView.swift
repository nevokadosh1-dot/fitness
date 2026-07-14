import SwiftUI
import SwiftData

/// Active workout tracking. Every change writes straight to SwiftData, so the
/// session survives app termination and can be resumed from Today or Train.
struct LiveWorkoutView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var showExercisePicker = false
    @State private var showDiscardConfirm = false
    @State private var showFinishSheet = false
    @State private var replacingExercise: WorkoutExercise?
    @State private var previousByName: [String: WorkoutExercise] = [:]
    @State private var bestByName: [String: PersonalRecord] = [:]

    private var settings: AppSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .kilograms }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    statusHeader
                    ForEach(session.orderedExercises, id: \.id) { exercise in
                        LiveExerciseCard(
                            exercise: exercise,
                            weightUnit: weightUnit,
                            showRPE: settings?.showRPE ?? true,
                            previous: previousByName[exercise.displayName],
                            best: bestByName[exercise.displayName],
                            onReplace: { replacingExercise = exercise },
                            onMoveUp: { move(exercise, by: -1) },
                            onMoveDown: { move(exercise, by: 1) },
                            onRemove: { remove(exercise) }
                        )
                    }
                    addExerciseButton
                    workoutNotes
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 100)
            }
            .background(Theme.background)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(session.name.isEmpty ? "Workout" : session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button(session.status == .paused ? "Resume" : "Pause") { togglePause() }
                        Button("Minimize") { dismiss() }
                        Button("Discard Workout", role: .destructive) { showDiscardConfirm = true }
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { showFinishSheet = true }
                        .font(.forgeHeadline)
                        .foregroundStyle(Theme.accent)
                        .accessibilityIdentifier("workout.finish")
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showExercisePicker) { pickerSheet { addExercise($0) } }
            .sheet(item: $replacingExercise) { exercise in
                pickerSheet { replacement in
                    replace(exercise, with: replacement)
                }
            }
            .sheet(isPresented: $showFinishSheet) {
                FinishWorkoutSheet(session: session) {
                    dismiss()
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) {
                    guard let settings else { return }
                    WorkoutService.discard(session, in: modelContext, settings: settings)
                    Haptics.warning()
                    dismiss()
                }
            } message: {
                Text("All sets from this session will be deleted. This cannot be undone.")
            }
            .task { loadContext() }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    // MARK: Header

    private var statusHeader: some View {
        Card {
            HStack(spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.status == .paused ? "PAUSED" : "ELAPSED")
                        .font(.forgeOverline)
                        .tracking(1)
                        .foregroundStyle(session.status == .paused ? Theme.body : Theme.textTertiary)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(RunningMath.formatDuration(session.duration))
                            .font(.forgeHero)
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(session.completedSetCount) sets done")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textSecondary)
                    Text(Formatting.volume(session.totalVolumeKg, unit: weightUnit))
                        .font(.forgeStat)
                        .foregroundStyle(Theme.accent)
                }
                Button {
                    togglePause()
                } label: {
                    Image(systemName: session.status == .paused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(session.status == .paused ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(session.status == .paused ? "Resume workout" : "Pause workout")
            }
        }
    }

    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            Label("Add Exercise", systemImage: "plus.circle.fill")
        }
        .buttonStyle(SecondaryButtonStyle(tint: Theme.accent))
        .accessibilityIdentifier("workout.addExercise")
    }

    private var workoutNotes: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Workout Notes")
                TextField("How is the session going?", text: $session.notes, axis: .vertical)
                    .font(.forgeBody)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2...6)
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Label("Minimize", systemImage: "chevron.down")
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(width: 140)

            Button {
                showFinishSheet = true
            } label: {
                Label("Finish Workout", systemImage: "checkmark")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(.ultraThinMaterial)
    }

    private func pickerSheet(onSelect: @escaping (Exercise) -> Void) -> some View {
        NavigationStack {
            ExerciseLibraryView { exercise in
                onSelect(exercise)
                showExercisePicker = false
                replacingExercise = nil
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Actions

    private func togglePause() {
        if session.status == .paused {
            WorkoutService.resume(session, in: modelContext)
        } else {
            WorkoutService.pause(session, in: modelContext)
        }
        Haptics.light()
    }

    private func addExercise(_ exercise: Exercise) {
        _ = WorkoutService.addExercise(exercise, to: session, in: modelContext)
        loadContext()
        Haptics.light()
    }

    private func replace(_ exercise: WorkoutExercise, with replacement: Exercise) {
        let fresh = WorkoutExercise(exercise: replacement, sortIndex: exercise.sortIndex)
        fresh.supersetGroup = exercise.supersetGroup
        fresh.session = session
        modelContext.insert(fresh)
        // Keep the set layout but clear logged values; targets no longer apply.
        for set in exercise.orderedSets {
            let newSet = CompletedSet(sortIndex: set.sortIndex, setType: set.setType)
            newSet.workoutExercise = fresh
            modelContext.insert(newSet)
        }
        modelContext.delete(exercise)
        try? modelContext.save()
        loadContext()
        Haptics.light()
    }

    private func move(_ exercise: WorkoutExercise, by offset: Int) {
        var ordered = session.orderedExercises
        guard let index = ordered.firstIndex(where: { $0.id == exercise.id }) else { return }
        let target = index + offset
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        for (newIndex, item) in ordered.enumerated() {
            item.sortIndex = newIndex
        }
        try? modelContext.save()
        Haptics.light()
    }

    private func remove(_ exercise: WorkoutExercise) {
        modelContext.delete(exercise)
        for (index, item) in session.orderedExercises.enumerated() {
            item.sortIndex = index
        }
        try? modelContext.save()
        Haptics.light()
    }

    private func loadContext() {
        var previous: [String: WorkoutExercise] = [:]
        for exercise in session.orderedExercises {
            let name = exercise.displayName
            if previous[name] == nil {
                previous[name] = WorkoutService.previousPerformance(exerciseName: name, in: modelContext, before: session.startedAt)
            }
        }
        previousByName = previous

        let records = (try? modelContext.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        var best: [String: PersonalRecord] = [:]
        for record in records where record.kind == .heaviestWeight {
            best[record.subject] = record
        }
        bestByName = best
    }
}
