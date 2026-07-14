import SwiftUI
import SwiftData
import Charts

/// Flexibility hub: routines, split progress and recent sessions.
struct FlexibilityHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FlexibilityRoutine.createdAt) private var routines: [FlexibilityRoutine]
    @Query(sort: \FlexibilitySession.date, order: .reverse) private var sessions: [FlexibilitySession]
    @Query(sort: \FlexibilityMeasurement.date) private var measurements: [FlexibilityMeasurement]

    @State private var liveRoutine: FlexibilityRoutine?
    @State private var showNewRoutine = false
    @State private var showMeasurementEntry = false

    private var activeRoutines: [FlexibilityRoutine] { routines.filter { !$0.isArchived } }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                routinesSection
                progressSection
                recentSessions
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
        .navigationTitle("Flexibility")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Routine", systemImage: "plus") { showNewRoutine = true }
                    Button("Log Measurement", systemImage: "ruler") { showMeasurementEntry = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fullScreenCover(item: $liveRoutine) { routine in
            LiveFlexibilityView(routine: routine)
        }
        .sheet(isPresented: $showNewRoutine) {
            FlexibilityRoutineEditorView(routine: nil)
        }
        .sheet(isPresented: $showMeasurementEntry) {
            FlexibilityMeasurementEntryView()
        }
    }

    // MARK: Routines

    private var routinesSection: some View {
        VStack(spacing: Spacing.s) {
            SectionHeader("Routines")
            if activeRoutines.isEmpty {
                Card {
                    EmptyStateView(
                        systemImage: "figure.flexibility",
                        title: "No routines",
                        message: "Build a stretching routine and run it as a guided session.",
                        actionTitle: "Create Routine"
                    ) { showNewRoutine = true }
                }
            }
            ForEach(activeRoutines, id: \.id) { routine in
                routineRow(routine)
            }
        }
    }

    private func routineRow(_ routine: FlexibilityRoutine) -> some View {
        NavigationLink {
            FlexibilityRoutineDetailView(routine: routine)
        } label: {
            Card(accent: Theme.flexibility) {
                HStack(spacing: Spacing.m) {
                    Image(systemName: routine.kind.symbolName)
                        .font(.title3)
                        .foregroundStyle(Theme.flexibility)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.name)
                            .font(.forgeHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(routine.items?.count ?? 0) stretches · ~\(max(1, routine.estimatedSeconds / 60)) min · \(weeklyDone(routine))/\(routine.targetSessionsPerWeek) this week")
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button("Start") {
                        Haptics.medium()
                        liveRoutine = routine
                    }
                    .buttonStyle(PillButtonStyle(tint: Theme.flexibility, filled: true))
                    .accessibilityIdentifier("flex.startRoutine")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func weeklyDone(_ routine: FlexibilityRoutine) -> Int {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return sessions.filter { $0.routineID == routine.id && $0.date >= weekStart }.count
    }

    // MARK: Progress

    @ViewBuilder
    private var progressSection: some View {
        if !measurements.isEmpty {
            VStack(spacing: Spacing.s) {
                SectionHeader("Split Progress", actionTitle: "Log") { showMeasurementEntry = true }
                ForEach(SplitTarget.allCases) { target in
                    splitChart(for: target)
                }
            }
        } else {
            Card {
                EmptyStateView(
                    systemImage: "ruler",
                    title: "No measurements yet",
                    message: "Track distance from the floor, block height or an angle to see split progress over time.",
                    actionTitle: "Log Measurement"
                ) { showMeasurementEntry = true }
            }
        }
    }

    @ViewBuilder
    private func splitChart(for target: SplitTarget) -> some View {
        // Chart the method with the most data for this split.
        let forTarget = measurements.filter { $0.targetRaw == target.rawValue }
        let byMethod = Dictionary(grouping: forTarget, by: \.methodRaw)
        if let preferred = byMethod.max(by: { $0.value.count < $1.value.count }),
           let method = FlexibilityMetricMethod(rawValue: preferred.key) {
            let points = preferred.value
            Card(accent: Theme.flexibility) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack {
                        Text(target.displayName)
                            .font(.forgeHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if let latest = points.max(by: { $0.date < $1.date }) {
                            Text("\(Formatting.trimmed(latest.value)) \(method.unitLabel)")
                                .font(.forgeStat)
                                .foregroundStyle(Theme.flexibility)
                        }
                    }
                    if points.count >= 2 {
                        Chart(points.sorted(by: { $0.date < $1.date }), id: \.id) { point in
                            LineMark(x: .value("Date", point.date), y: .value(method.displayName, point.value))
                                .foregroundStyle(Theme.flexibility)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", point.date), y: .value(method.displayName, point.value))
                                .foregroundStyle(Theme.flexibility)
                                .symbolSize(20)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 110)
                        Text(method.lowerIsBetter ? "\(method.displayName) — lower is better" : method.displayName)
                            .font(.forgeOverline)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: Recent sessions

    @ViewBuilder
    private var recentSessions: some View {
        if !sessions.isEmpty {
            VStack(spacing: Spacing.s) {
                SectionHeader("Recent Sessions")
                ForEach(sessions.prefix(8), id: \.id) { session in
                    Card {
                        HStack {
                            Image(systemName: session.kind.symbolName)
                                .foregroundStyle(Theme.flexibility)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.routineNameSnapshot)
                                    .font(.forgeSubheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(Formatting.mediumDate(session.date)) · \(Formatting.workoutDuration(session.durationSeconds))")
                                    .font(.forgeCaption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if let intensity = session.intensity {
                                Text("Intensity \(intensity)/10")
                                    .font(.forgeCaption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            modelContext.delete(session)
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
    }
}

/// Manual split-measurement entry.
struct FlexibilityMeasurementEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var target: SplitTarget = .middle
    @State private var method: FlexibilityMetricMethod = .floorDistance
    @State private var value: Double = 0
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurement") {
                    Picker("Split", selection: $target) {
                        ForEach(SplitTarget.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Method", selection: $method) {
                        ForEach(FlexibilityMetricMethod.allCases) { Text($0.displayName).tag($0) }
                    }
                    HStack {
                        Text("Value")
                        Spacer()
                        TextField("0", value: $value, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text(method.unitLabel).foregroundStyle(Theme.textSecondary)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Notes") {
                    TextField("Warm or cold? Anything different?", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Text(method.lowerIsBetter
                         ? "For \(method.displayName.lowercased()), a smaller number means deeper — progress shows as the line going down."
                         : "For \(method.displayName.lowercased()), a bigger number is better.")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Log Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let measurement = FlexibilityMeasurement(date: date, target: target, method: method, value: value, notes: notes)
                        modelContext.insert(measurement)
                        try? modelContext.save()
                        PRService.recompute(in: modelContext)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(value <= 0 && method != .floorDistance)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
