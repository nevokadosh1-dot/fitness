import SwiftUI
import SwiftData

/// Manual run entry / editing, including splits and quick benchmark distances.
struct RunEditorView: View {
    var run: RunningSession?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var date = Date()
    @State private var runType: RunType = .easy
    @State private var customRunType = ""
    @State private var distanceDisplay: Double = 0
    @State private var durationSeconds: Double = 0
    @State private var surface: RunSurface = .road
    @State private var routeType: RouteType = .loop
    @State private var rpe: Double?
    @State private var heartRate: Double?
    @State private var calories: Double?
    @State private var intervalStructure = ""
    @State private var notes = ""
    @State private var splits: [(distance: Double, duration: Double)] = []
    @State private var loaded = false

    private var settings: AppSettings? { settingsList.first }
    private var distanceUnit: DistanceUnit { settings?.distanceUnit ?? .kilometers }

    private var distanceMeters: Double {
        UnitsConverter.distanceMeters(fromDisplay: distanceDisplay, unit: distanceUnit)
    }
    private var canSave: Bool { distanceMeters > 0 && durationSeconds > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Run") {
                    DatePicker("Date & time", selection: $date)
                    Picker("Type", selection: $runType) {
                        ForEach(RunType.allCases) { Text($0.displayName).tag($0) }
                    }
                    if runType == .custom {
                        TextField("Custom type name", text: $customRunType)
                    }
                }

                Section("Distance & Time") {
                    benchmarkChips
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0", value: $distanceDisplay, format: .number.precision(.fractionLength(0...3)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .accessibilityIdentifier("run.distance")
                        Text(distanceUnit.suffix).foregroundStyle(Theme.textSecondary)
                    }
                    DurationField(label: "Duration", totalSeconds: $durationSeconds)
                        .listRowSeparator(.hidden)
                    if let pace = RunningMath.paceSecondsPerKm(distanceMeters: distanceMeters, durationSeconds: durationSeconds) {
                        LabeledContent("Average pace") {
                            Text(RunningMath.formatPace(secondsPerKm: pace, unit: distanceUnit))
                                .foregroundStyle(Theme.running)
                        }
                    }
                }

                Section("Splits") {
                    ForEach(splits.indices, id: \.self) { index in
                        HStack {
                            Text("#\(index + 1)")
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textTertiary)
                            TextField("m", value: $splits[index].distance, format: .number)
                                .keyboardType(.decimalPad)
                            Text("m ·").foregroundStyle(Theme.textSecondary)
                            TextField("sec", value: $splits[index].duration, format: .number)
                                .keyboardType(.decimalPad)
                            Text("s").foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .onDelete { splits.remove(atOffsets: $0) }
                    Button {
                        splits.append((distance: 1000, duration: 0))
                    } label: {
                        Label("Add Split", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.running)
                    }
                }

                Section("Conditions") {
                    Picker("Surface", selection: $surface) {
                        ForEach(RunSurface.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Route", selection: $routeType) {
                        ForEach(RouteType.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section("Effort & Physiology") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Effort (RPE)").font(.forgeCaption).foregroundStyle(Theme.textSecondary)
                        RPESelector(rpe: $rpe)
                    }
                    HStack {
                        Text("Avg heart rate")
                        Spacer()
                        TextField("Optional", value: $heartRate, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("bpm").foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Optional", value: $calories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("kcal").foregroundStyle(Theme.textSecondary)
                    }
                }

                Section("Notes") {
                    if runType == .interval || !intervalStructure.isEmpty {
                        TextField("Interval structure, e.g. 6 × 400 m / 90 s", text: $intervalStructure)
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(run == nil ? "Log Run" : "Edit Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("run.save")
                }
            }
            .onAppear { loadIfNeeded() }
        }
        .preferredColorScheme(.dark)
    }

    private var benchmarkChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(BenchmarkDistance.allCases) { benchmark in
                    Button {
                        distanceDisplay = UnitsConverter.displayDistance(meters: benchmark.meters, unit: distanceUnit)
                        if benchmark == .sprint100m { runType = .timeTrial }
                        Haptics.light()
                    } label: {
                        TagChip(text: benchmark.displayName, tint: Theme.running,
                                isSelected: abs(distanceMeters - benchmark.meters) < 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let run else { return }
        date = run.date
        runType = run.runType
        if run.runType == .custom { customRunType = run.runTypeRaw }
        distanceDisplay = UnitsConverter.displayDistance(meters: run.distanceMeters, unit: distanceUnit)
        durationSeconds = run.durationSeconds
        surface = RunSurface(rawValue: run.surfaceRaw) ?? .road
        routeType = RouteType(rawValue: run.routeTypeRaw) ?? .loop
        rpe = run.rpe
        heartRate = run.averageHeartRate
        calories = run.calories
        intervalStructure = run.intervalStructure
        notes = run.notes
        splits = run.orderedSplits.map { ($0.distanceMeters, $0.durationSeconds) }
    }

    private func save() {
        let target: RunningSession
        if let run {
            target = run
            for split in target.splits ?? [] { modelContext.delete(split) }
        } else {
            target = RunningSession()
            modelContext.insert(target)
        }
        target.date = date
        target.runTypeRaw = runType == .custom && !customRunType.isEmpty
            ? customRunType.lowercased() : runType.rawValue
        target.distanceMeters = distanceMeters
        target.durationSeconds = durationSeconds
        target.surfaceRaw = surface.rawValue
        target.routeTypeRaw = routeType.rawValue
        target.rpe = rpe
        target.averageHeartRate = heartRate
        target.calories = calories
        target.intervalStructure = intervalStructure
        target.notes = notes
        for (index, splitValues) in splits.enumerated() where splitValues.duration > 0 {
            let split = RunningSplit(sortIndex: index, distanceMeters: splitValues.distance, durationSeconds: splitValues.duration)
            split.session = target
            modelContext.insert(split)
        }
        try? modelContext.save()
        PRService.recompute(in: modelContext)
        Haptics.success()
        dismiss()
    }
}

/// Read-only run details with edit and delete.
struct RunDetailView: View {
    @Bindable var run: RunningSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var settings: AppSettings? { settingsList.first }
    private var distanceUnit: DistanceUnit { settings?.distanceUnit ?? .kilometers }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                HeroCard(tint: Theme.running) {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text(RunType.displayName(for: run.runTypeRaw))
                            .font(.forgeTitle)
                            .foregroundStyle(Theme.textPrimary)
                        Text(run.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: Spacing.l) {
                            StatTile(label: "Distance", value: Formatting.distance(run.distanceMeters, unit: distanceUnit), tint: Theme.running)
                            StatTile(label: "Time", value: run.matchedBenchmark == .sprint100m
                                     ? RunningMath.formatSprintTime(run.durationSeconds)
                                     : RunningMath.formatDuration(run.durationSeconds))
                            StatTile(label: "Pace", value: run.paceSecondsPerKm.map { RunningMath.formatPace(secondsPerKm: $0, unit: distanceUnit) } ?? "—")
                        }
                        HStack(spacing: Spacing.l) {
                            if let rpe = run.rpe {
                                StatTile(label: "RPE", value: Formatting.trimmed(rpe, maxDecimals: 1))
                            }
                            if let heartRate = run.averageHeartRate {
                                StatTile(label: "Avg HR", value: "\(Int(heartRate)) bpm")
                            }
                            if let calories = run.calories {
                                StatTile(label: "Energy", value: "\(Int(calories)) kcal")
                            }
                        }
                        HStack(spacing: Spacing.s) {
                            TagChip(text: RunSurface(rawValue: run.surfaceRaw)?.displayName ?? run.surfaceRaw, tint: Theme.running)
                            TagChip(text: RouteType(rawValue: run.routeTypeRaw)?.displayName ?? run.routeTypeRaw, tint: Theme.neutral)
                            if run.source == "healthkit" {
                                TagChip(text: "From Health", tint: Theme.danger)
                            }
                        }
                    }
                }

                if !run.orderedSplits.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            SectionHeader("Splits")
                            ForEach(run.orderedSplits, id: \.id) { split in
                                HStack {
                                    Text("#\(split.sortIndex + 1)")
                                        .font(.forgeCaption)
                                        .foregroundStyle(Theme.textTertiary)
                                        .frame(width: 30, alignment: .leading)
                                    Text(Formatting.distance(split.distanceMeters, unit: distanceUnit))
                                        .font(.forgeSubheadline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text(RunningMath.formatDuration(split.durationSeconds))
                                        .font(.forgeSubheadline)
                                        .foregroundStyle(Theme.textSecondary)
                                    if let pace = split.paceSecondsPerKm {
                                        Text(RunningMath.formatPace(secondsPerKm: pace, unit: distanceUnit))
                                            .font(.forgeCaption)
                                            .foregroundStyle(Theme.running)
                                    }
                                }
                            }
                        }
                    }
                }

                if !run.intervalStructure.isEmpty || !run.notes.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            SectionHeader("Notes")
                            if !run.intervalStructure.isEmpty {
                                Label(run.intervalStructure, systemImage: "repeat")
                                    .font(.forgeSubheadline)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            if !run.notes.isEmpty {
                                Text(run.notes)
                                    .font(.forgeBody)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }

                Button {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Run", systemImage: "trash")
                }
                .buttonStyle(DangerButtonStyle())
            }
            .padding(Spacing.l)
        }
        .background(Theme.background)
        .navigationTitle("Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            RunEditorView(run: run)
        }
        .confirmationDialog("Delete this run?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Run", role: .destructive) {
                modelContext.delete(run)
                try? modelContext.save()
                PRService.recompute(in: modelContext)
                dismiss()
            }
        } message: {
            Text("Running records will be recalculated.")
        }
    }
}
