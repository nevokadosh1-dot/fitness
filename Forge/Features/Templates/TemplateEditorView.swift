import SwiftUI
import SwiftData

/// Create or edit a workout template: exercises, order, supersets, planned sets.
struct TemplateEditorView: View {
    var template: WorkoutTemplate?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var details = ""
    @State private var colorHex = "#4AC766"
    @State private var iconName = "dumbbell.fill"
    @State private var estimatedMinutes: Int?
    @State private var workingTemplate: WorkoutTemplate?
    @State private var showExercisePicker = false
    @State private var loaded = false

    private let icons = ["dumbbell.fill", "figure.strengthtraining.traditional",
                         "figure.strengthtraining.functional", "flame.fill",
                         "bolt.fill", "figure.core.training", "figure.arms.open", "scalemass.fill"]

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("template.name")
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(2...4)
                    HStack {
                        Text("Est. minutes")
                        Spacer()
                        TextField("Optional", value: $estimatedMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }

                Section("Appearance") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.s) {
                            ForEach(Color.templatePalette, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if hex == colorHex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.black)
                                        }
                                    }
                                    .onTapGesture { colorHex = hex }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.s) {
                            ForEach(icons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.body)
                                    .foregroundStyle(icon == iconName ? Color.black : Theme.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(icon == iconName ? Color(hex: colorHex) : Theme.surfaceElevated))
                                    .onTapGesture { iconName = icon }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    if let workingTemplate {
                        ForEach(workingTemplate.orderedExercises, id: \.id) { templateExercise in
                            NavigationLink {
                                TemplateExerciseEditorView(templateExercise: templateExercise)
                            } label: {
                                exerciseRow(templateExercise)
                            }
                        }
                        .onMove { source, destination in
                            moveExercises(source: source, destination: destination)
                        }
                        .onDelete { offsets in
                            deleteExercises(at: offsets)
                        }
                    }
                    Button {
                        ensureWorkingTemplate()
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityIdentifier("template.addExercise")
                } header: {
                    Text("Exercises")
                } footer: {
                    Text("Give two exercises the same superset number to pair them. Drag to reorder.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("template.save")
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                NavigationStack {
                    ExerciseLibraryView { exercise in
                        addExercise(exercise)
                        showExercisePicker = false
                    }
                }
                .preferredColorScheme(.dark)
            }
            .onAppear { loadIfNeeded() }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private func exerciseRow(_ templateExercise: TemplateExercise) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Spacing.xs) {
                if let group = templateExercise.supersetGroup {
                    TagChip(text: "SS\(group)", tint: Theme.gold, isSelected: true)
                }
                Text(templateExercise.displayName)
                    .foregroundStyle(Theme.textPrimary)
            }
            Text("\(templateExercise.plannedSets?.count ?? 0) sets")
                .font(.forgeCaption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Data plumbing
    // Editing operates on a real (possibly fresh) model object so relationships
    // work naturally; on cancel a freshly created template is deleted again.

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let template {
            workingTemplate = template
            name = template.name
            details = template.details
            colorHex = template.colorHex
            iconName = template.iconName
            estimatedMinutes = template.estimatedMinutes
        }
    }

    private func ensureWorkingTemplate() {
        if workingTemplate == nil {
            let fresh = WorkoutTemplate(name: name.isEmpty ? "New Template" : name)
            modelContext.insert(fresh)
            workingTemplate = fresh
        }
    }

    private func addExercise(_ exercise: Exercise) {
        guard let workingTemplate else { return }
        let nextIndex = ((workingTemplate.exercises ?? []).map(\.sortIndex).max() ?? -1) + 1
        let templateExercise = TemplateExercise(exercise: exercise, sortIndex: nextIndex)
        templateExercise.template = workingTemplate
        modelContext.insert(templateExercise)
        for setIndex in 0..<3 {
            let planned = PlannedSet(sortIndex: setIndex)
            planned.targetRepsMin = 8
            planned.targetRepsMax = 12
            planned.templateExercise = templateExercise
            modelContext.insert(planned)
        }
        Haptics.light()
    }

    private func moveExercises(source: IndexSet, destination: Int) {
        guard let workingTemplate else { return }
        var ordered = workingTemplate.orderedExercises
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in ordered.enumerated() {
            exercise.sortIndex = index
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        guard let workingTemplate else { return }
        let ordered = workingTemplate.orderedExercises
        for offset in offsets {
            modelContext.delete(ordered[offset])
        }
        for (index, exercise) in workingTemplate.orderedExercises.enumerated() {
            exercise.sortIndex = index
        }
    }

    private func save() {
        ensureWorkingTemplate()
        guard let workingTemplate else { return }
        workingTemplate.name = name.trimmingCharacters(in: .whitespaces)
        workingTemplate.details = details
        workingTemplate.colorHex = colorHex
        workingTemplate.iconName = iconName
        workingTemplate.estimatedMinutes = estimatedMinutes
        workingTemplate.updatedAt = Date()
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    private func cancel() {
        // A template created during this editing session is removed on cancel.
        if template == nil, let workingTemplate {
            modelContext.delete(workingTemplate)
            try? modelContext.save()
        }
        dismiss()
    }
}

/// Per-exercise editing inside a template: planned sets, superset group, notes.
struct TemplateExerciseEditorView: View {
    @Bindable var templateExercise: TemplateExercise

    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .kilograms }

    var body: some View {
        Form {
            Section("Sets") {
                ForEach(templateExercise.orderedPlannedSets, id: \.id) { planned in
                    PlannedSetRow(planned: planned, weightUnit: weightUnit)
                }
                .onDelete { offsets in
                    let ordered = templateExercise.orderedPlannedSets
                    for offset in offsets { modelContext.delete(ordered[offset]) }
                    for (index, set) in templateExercise.orderedPlannedSets.enumerated() {
                        set.sortIndex = index
                    }
                }
                Button {
                    let ordered = templateExercise.orderedPlannedSets
                    let planned = PlannedSet(sortIndex: (ordered.map(\.sortIndex).max() ?? -1) + 1)
                    if let last = ordered.last {
                        planned.setTypeRaw = last.setTypeRaw
                        planned.targetRepsMin = last.targetRepsMin
                        planned.targetRepsMax = last.targetRepsMax
                        planned.targetWeightKg = last.targetWeightKg
                        planned.targetRPE = last.targetRPE
                    }
                    planned.templateExercise = templateExercise
                    modelContext.insert(planned)
                    Haptics.light()
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
            }

            Section("Grouping") {
                Picker("Superset group", selection: Binding(
                    get: { templateExercise.supersetGroup ?? 0 },
                    set: { templateExercise.supersetGroup = $0 == 0 ? nil : $0 }
                )) {
                    Text("None").tag(0)
                    ForEach(1...4, id: \.self) { Text("Group \($0)").tag($0) }
                }
            }

            Section("Notes") {
                TextField("Cues, setup, tempo…", text: $templateExercise.notes, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(templateExercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PlannedSetRow: View {
    @Bindable var planned: PlannedSet
    var weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Picker("Type", selection: Binding(
                get: { planned.setType },
                set: { planned.setType = $0 }
            )) {
                ForEach(SetType.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)

            HStack {
                repsField("Min", value: $planned.targetRepsMin)
                repsField("Max", value: $planned.targetRepsMax)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight (\(weightUnit.suffix))")
                        .font(.forgeOverline).foregroundStyle(Theme.textTertiary)
                    TextField("—", value: Binding(
                        get: { planned.targetWeightKg.map { UnitsConverter.displayWeight(kg: $0, unit: weightUnit) } },
                        set: { planned.targetWeightKg = $0.map { UnitsConverter.weightKg(fromDisplay: $0, unit: weightUnit) } }
                    ), format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("RPE")
                        .font(.forgeOverline).foregroundStyle(Theme.textTertiary)
                    TextField("—", value: $planned.targetRPE, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func repsField(_ label: String, value: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.forgeOverline).foregroundStyle(Theme.textTertiary)
            TextField("—", value: value, format: .number)
                .keyboardType(.numberPad)
        }
    }
}
