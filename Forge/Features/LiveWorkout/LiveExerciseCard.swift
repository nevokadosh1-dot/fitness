import SwiftUI
import SwiftData

/// One exercise inside the live workout: previous performance, targets and sets.
struct LiveExerciseCard: View {
    @Bindable var exercise: WorkoutExercise
    var weightUnit: WeightUnit
    var showRPE: Bool
    var previous: WorkoutExercise?
    var best: PersonalRecord?
    var onReplace: () -> Void
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showNotes = false
    @State private var showRemoveConfirm = false

    var body: some View {
        Card(accent: Theme.accent) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header
                context
                setsTable
                HStack {
                    Button {
                        _ = WorkoutService.addSet(to: exercise, in: modelContext)
                        Haptics.light()
                    } label: {
                        Label("Add Set", systemImage: "plus")
                    }
                    .buttonStyle(PillButtonStyle(tint: Theme.accent))
                    .accessibilityIdentifier("workout.addSet")
                    Spacer()
                    if showNotes || !exercise.notes.isEmpty {
                        EmptyView()
                    } else {
                        Button("Notes") { showNotes = true }
                            .buttonStyle(PillButtonStyle(tint: Theme.neutral))
                    }
                }
                if showNotes || !exercise.notes.isEmpty {
                    TextField("Exercise notes", text: $exercise.notes, axis: .vertical)
                        .font(.forgeSubheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1...4)
                }
            }
        }
        .confirmationDialog("Remove \(exercise.displayName)?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove Exercise", role: .destructive) { onRemove() }
        }
    }

    private var header: some View {
        HStack {
            if let group = exercise.supersetGroup {
                TagChip(text: "SS\(group)", tint: Theme.gold, isSelected: true)
            }
            Text(exercise.displayName)
                .font(.forgeHeadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Menu {
                Button("Replace Exercise", systemImage: "arrow.triangle.2.circlepath") { onReplace() }
                Button("Move Up", systemImage: "arrow.up") { onMoveUp() }
                Button("Move Down", systemImage: "arrow.down") { onMoveDown() }
                Button("Remove", systemImage: "trash", role: .destructive) { showRemoveConfirm = true }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var context: some View {
        let previousSummary = previous.map(summary(of:))
        if previousSummary != nil || best != nil {
            HStack(spacing: Spacing.m) {
                if let previousSummary {
                    Label(previousSummary, systemImage: "clock.arrow.circlepath")
                }
                if let best {
                    Label(best.detail, systemImage: "trophy.fill")
                        .foregroundStyle(Theme.gold)
                }
            }
            .font(.forgeCaption)
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private func summary(of previous: WorkoutExercise) -> String {
        let sets = previous.orderedSets.filter { $0.isCompleted && $0.setType.countsAsWorking }
        guard !sets.isEmpty else { return "No previous data" }
        if let top = sets.max(by: { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }),
           let weight = top.weightKg, let reps = top.reps {
            return "Last: \(sets.count)×, top \(Formatting.weight(weight, unit: weightUnit)) × \(reps)"
        }
        return "Last: \(sets.count) sets"
    }

    private var setsTable: some View {
        VStack(spacing: Spacing.s) {
            ForEach(exercise.orderedSets, id: \.id) { set in
                LiveSetRow(
                    set: set,
                    exercise: exercise,
                    weightUnit: weightUnit,
                    showRPE: showRPE && exercise.tracksRPE
                )
            }
        }
    }
}

/// A single set row: type badge, weight/reps quick-adjust, RPE, done toggle.
struct LiveSetRow: View {
    @Bindable var set: CompletedSet
    var exercise: WorkoutExercise
    var weightUnit: WeightUnit
    var showRPE: Bool

    @Environment(\.modelContext) private var modelContext

    private var weightBinding: Binding<Double> {
        Binding(
            get: { UnitsConverter.displayWeight(kg: set.weightKg ?? 0, unit: weightUnit) },
            set: { set.weightKg = UnitsConverter.weightKg(fromDisplay: max(0, $0), unit: weightUnit) }
        )
    }

    private var increment: Double {
        let kg = exercise.incrementKg > 0 ? exercise.incrementKg : 2.5
        return weightUnit == .kilograms ? kg : (kg / UnitsConverter.kgPerPound).rounded()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                setTypeBadge
                if let target = set.targetText {
                    Text("Target \(target)")
                        .font(.forgeOverline)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                if showRPE {
                    Menu {
                        Button("No RPE") { set.rpe = nil }
                        ForEach([6.0, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10], id: \.self) { value in
                            Button("RPE \(Formatting.trimmed(value, maxDecimals: 1))") { set.rpe = value }
                        }
                    } label: {
                        Text(set.rpe.map { "RPE \(Formatting.trimmed($0, maxDecimals: 1))" } ?? "RPE —")
                            .font(.forgeCaption)
                            .foregroundStyle(set.rpe == nil ? Theme.textTertiary : Theme.accent)
                    }
                }
                Menu {
                    Button("Delete Set", role: .destructive) { deleteSet() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 24, height: 24)
                }
            }

            HStack(spacing: Spacing.s) {
                if exercise.usesWeight {
                    quickAdjust(
                        value: weightBinding,
                        step: increment,
                        unit: weightUnit.suffix,
                        decimals: 2
                    )
                }
                if exercise.usesReps {
                    repsAdjust
                }
                if exercise.usesDuration {
                    durationEntry
                }
                doneButton
            }
        }
        .padding(Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                .fill(set.isCompleted ? Theme.accent.opacity(0.08) : Theme.surfaceElevated.opacity(0.5))
        )
    }

    private var setTypeBadge: some View {
        Menu {
            ForEach(SetType.allCases) { type in
                Button(type.displayName) { set.setType = type }
            }
        } label: {
            Text(badgeText)
                .font(.forgeCaption.bold())
                .foregroundStyle(badgeColor)
                .frame(width: 34, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(badgeColor.opacity(0.15)))
        }
    }

    private var badgeText: String {
        let type = set.setType
        return type == .working ? "\(set.sortIndex + 1)" : type.shortLabel
    }

    private var badgeColor: Color {
        switch set.setType {
        case .warmup: return Theme.running
        case .working: return Theme.textSecondary
        case .backoff: return Theme.flexibility
        case .dropSet: return Theme.body
        case .failure: return Theme.danger
        case .custom: return Theme.gold
        }
    }

    private func quickAdjust(value: Binding<Double>, step: Double, unit: String, decimals: Int) -> some View {
        HStack(spacing: 4) {
            IconButton(systemImage: "minus", size: 30) {
                value.wrappedValue = max(0, value.wrappedValue - step)
                Haptics.light()
            }
            VStack(spacing: 0) {
                TextField("0", value: value, format: .number.precision(.fractionLength(0...decimals)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.forgeStat)
                    .foregroundStyle(Theme.textPrimary)
                Text(unit)
                    .font(.forgeOverline)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(minWidth: 52)
            IconButton(systemImage: "plus", size: 30) {
                value.wrappedValue += step
                Haptics.light()
            }
        }
    }

    private var repsAdjust: some View {
        HStack(spacing: 4) {
            IconButton(systemImage: "minus", size: 30) {
                set.reps = max(0, (set.reps ?? 0) - 1)
                Haptics.light()
            }
            VStack(spacing: 0) {
                TextField("0", value: Binding(get: { set.reps ?? 0 }, set: { set.reps = max(0, $0) }), format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.forgeStat)
                    .foregroundStyle(Theme.textPrimary)
                Text("reps")
                    .font(.forgeOverline)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(minWidth: 40)
            IconButton(systemImage: "plus", size: 30) {
                set.reps = (set.reps ?? 0) + 1
                Haptics.light()
            }
        }
    }

    private var durationEntry: some View {
        VStack(spacing: 0) {
            TextField("0", value: Binding(
                get: { Int((set.durationSeconds ?? 0)) },
                set: { set.durationSeconds = TimeInterval(max(0, $0)) }
            ), format: .number)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.forgeStat)
            .foregroundStyle(Theme.textPrimary)
            Text("seconds")
                .font(.forgeOverline)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(minWidth: 60)
    }

    private var doneButton: some View {
        Button {
            set.isCompleted.toggle()
            set.completedAt = set.isCompleted ? Date() : nil
            try? modelContext.save()
            if set.isCompleted { Haptics.success() } else { Haptics.light() }
        } label: {
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 28))
                .foregroundStyle(set.isCompleted ? Theme.accent : Theme.textTertiary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel(set.isCompleted ? "Mark set incomplete" : "Complete set")
        .accessibilityIdentifier("workout.completeSet")
    }

    private func deleteSet() {
        guard let parent = set.workoutExercise else { return }
        modelContext.delete(set)
        for (index, remaining) in parent.orderedSets.enumerated() {
            remaining.sortIndex = index
        }
        try? modelContext.save()
        Haptics.light()
    }
}
