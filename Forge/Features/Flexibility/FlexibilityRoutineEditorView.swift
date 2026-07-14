import SwiftUI
import SwiftData

/// Routine details with a start button and per-item overview.
struct FlexibilityRoutineDetailView: View {
    @Bindable var routine: FlexibilityRoutine

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var liveRoutine: FlexibilityRoutine?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                HeroCard(tint: Theme.flexibility) {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        HStack {
                            Image(systemName: routine.kind.symbolName)
                                .font(.title2)
                                .foregroundStyle(Theme.flexibility)
                            Text(routine.kind.displayName)
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if !routine.details.isEmpty {
                            Text(routine.details)
                                .font(.forgeSubheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        HStack(spacing: Spacing.l) {
                            StatTile(label: "Stretches", value: "\(routine.items?.count ?? 0)")
                            StatTile(label: "Est. Time", value: "~\(max(1, routine.estimatedSeconds / 60)) min")
                            StatTile(label: "Target", value: "\(routine.targetSessionsPerWeek)×/week")
                        }
                        Button {
                            Haptics.medium()
                            liveRoutine = routine
                        } label: {
                            Label("Start Session", systemImage: "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle(tint: Theme.flexibility))
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        SectionHeader("Stretches")
                        ForEach(routine.orderedItems, id: \.id) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(.forgeHeadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(item.sets) × \(item.holdSeconds)s hold\(item.sideMode == .leftRight ? " per side" : "") · \(item.restSeconds)s rest")
                                    .font(.forgeCaption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            if item.id != routine.orderedItems.last?.id {
                                Divider().overlay(Theme.separator)
                            }
                        }
                    }
                }

                VStack(spacing: Spacing.s) {
                    Button {
                        routine.isArchived.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(routine.isArchived ? "Restore" : "Archive", systemImage: "archivebox")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Routine", systemImage: "trash")
                    }
                    .buttonStyle(DangerButtonStyle())
                }
            }
            .padding(Spacing.l)
        }
        .background(Theme.background)
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            FlexibilityRoutineEditorView(routine: routine)
        }
        .fullScreenCover(item: $liveRoutine) { live in
            LiveFlexibilityView(routine: live)
        }
        .confirmationDialog("Delete this routine?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Routine", role: .destructive) {
                modelContext.delete(routine)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Past sessions logged from it are kept.")
        }
    }
}

/// Create or edit a flexibility routine and its ordered items.
struct FlexibilityRoutineEditorView: View {
    var routine: FlexibilityRoutine?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FlexibilityExercise.name) private var library: [FlexibilityExercise]

    @State private var name = ""
    @State private var kind: FlexibilityKind = .mobility
    @State private var details = ""
    @State private var targetPerWeek = 2
    @State private var workingRoutine: FlexibilityRoutine?
    @State private var showStretchPicker = false
    @State private var newStretchName = ""
    @State private var loaded = false

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(FlexibilityKind.allCases) { Text($0.displayName).tag($0) }
                    }
                    Stepper("Target: \(targetPerWeek)×/week", value: $targetPerWeek, in: 1...14)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Stretches") {
                    if let workingRoutine {
                        ForEach(workingRoutine.orderedItems, id: \.id) { item in
                            NavigationLink {
                                FlexibilityItemEditorView(item: item)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("\(item.sets) × \(item.holdSeconds)s\(item.sideMode == .leftRight ? " per side" : "")")
                                        .font(.forgeCaption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .onMove { source, destination in
                            var ordered = workingRoutine.orderedItems
                            ordered.move(fromOffsets: source, toOffset: destination)
                            for (index, item) in ordered.enumerated() { item.sortIndex = index }
                        }
                        .onDelete { offsets in
                            let ordered = workingRoutine.orderedItems
                            for offset in offsets { modelContext.delete(ordered[offset]) }
                            for (index, item) in workingRoutine.orderedItems.enumerated() { item.sortIndex = index }
                        }
                    }
                    Button {
                        ensureWorkingRoutine()
                        showStretchPicker = true
                    } label: {
                        Label("Add Stretch", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.flexibility)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .sheet(isPresented: $showStretchPicker) { stretchPicker }
            .onAppear { loadIfNeeded() }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private var stretchPicker: some View {
        NavigationStack {
            List {
                Section("New Stretch") {
                    HStack {
                        TextField("Name a new stretch", text: $newStretchName)
                        Button("Add") {
                            let trimmed = newStretchName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            let exercise = FlexibilityExercise(name: trimmed)
                            modelContext.insert(exercise)
                            addItem(exercise)
                            newStretchName = ""
                            showStretchPicker = false
                        }
                        .disabled(newStretchName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("Library") {
                    ForEach(library.filter { !$0.isArchived }, id: \.id) { exercise in
                        Button {
                            addItem(exercise)
                            showStretchPicker = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name).foregroundStyle(Theme.textPrimary)
                                if !exercise.targetArea.isEmpty {
                                    Text(exercise.targetArea)
                                        .font(.forgeCaption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Add Stretch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showStretchPicker = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let routine {
            workingRoutine = routine
            name = routine.name
            kind = routine.kind
            details = routine.details
            targetPerWeek = routine.targetSessionsPerWeek
        }
    }

    private func ensureWorkingRoutine() {
        if workingRoutine == nil {
            let fresh = FlexibilityRoutine(name: name.isEmpty ? "New Routine" : name, kind: kind)
            modelContext.insert(fresh)
            workingRoutine = fresh
        }
    }

    private func addItem(_ exercise: FlexibilityExercise) {
        guard let workingRoutine else { return }
        let nextIndex = ((workingRoutine.items ?? []).map(\.sortIndex).max() ?? -1) + 1
        let item = FlexibilityRoutineItem(exercise: exercise, sortIndex: nextIndex)
        item.routine = workingRoutine
        modelContext.insert(item)
        Haptics.light()
    }

    private func save() {
        ensureWorkingRoutine()
        guard let workingRoutine else { return }
        workingRoutine.name = name.trimmingCharacters(in: .whitespaces)
        workingRoutine.kind = kind
        workingRoutine.details = details
        workingRoutine.targetSessionsPerWeek = targetPerWeek
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }

    private func cancel() {
        if routine == nil, let workingRoutine {
            modelContext.delete(workingRoutine)
            try? modelContext.save()
        }
        dismiss()
    }
}

/// Edit a single routine item: hold, sets, sides, rest, notes.
struct FlexibilityItemEditorView: View {
    @Bindable var item: FlexibilityRoutineItem

    var body: some View {
        Form {
            Section("Timing") {
                Stepper("Hold: \(item.holdSeconds)s", value: $item.holdSeconds, in: 5...600, step: 5)
                Stepper("Sets: \(item.sets)", value: $item.sets, in: 1...10)
                Stepper("Rest: \(item.restSeconds)s", value: $item.restSeconds, in: 0...300, step: 5)
            }
            Section("Sides") {
                Picker("Sides", selection: Binding(
                    get: { item.sideMode },
                    set: { item.sideMode = $0 }
                )) {
                    ForEach(SideMode.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section("Notes") {
                TextField("Setup, props, cues…", text: $item.notes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
