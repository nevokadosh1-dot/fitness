import SwiftUI
import SwiftData
import Charts

/// Body tracking: weight, girths, body fat and custom metrics with charts,
/// range comparison and weekly/monthly averages.
struct BodyMeasurementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMeasurementEntry.date, order: .reverse) private var allEntries: [BodyMeasurementEntry]
    @Query private var settingsList: [AppSettings]

    @State private var selectedMetric = BodyMetric.bodyWeight.rawValue
    @State private var rangeDays = 90
    @State private var showEntrySheet = false
    @State private var editingEntry: BodyMeasurementEntry?

    private var settings: AppSettings? { settingsList.first }

    private var metricOptions: [String] {
        BodyMetric.allCases.map(\.rawValue) +
        (settings?.customBodyMetrics.map { BodyMetric.customPrefix + $0 } ?? [])
    }

    private var entries: [BodyMeasurementEntry] {
        allEntries.filter { $0.metricRaw == selectedMetric }
    }

    private var rangedEntries: [BodyMeasurementEntry] {
        guard rangeDays > 0 else { return entries }
        let cutoff = Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoff }
    }

    private var unitLabel: String {
        if let metric = BodyMetric(rawValue: selectedMetric) {
            if metric.isMass { return (settings?.weightUnit ?? .kilograms).suffix }
            if metric.isPercent { return "%" }
        }
        return (settings?.lengthUnit ?? .centimeters).suffix
    }

    private func displayValue(_ canonical: Double) -> Double {
        if let metric = BodyMetric(rawValue: selectedMetric) {
            if metric.isMass { return UnitsConverter.displayWeight(kg: canonical, unit: settings?.weightUnit ?? .kilograms) }
            if metric.isPercent { return canonical }
        }
        return UnitsConverter.displayLength(cm: canonical, unit: settings?.lengthUnit ?? .centimeters)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                metricPicker
                rangePicker
                chartCard
                averagesCard
                entriesList
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingEntry = nil
                    showEntrySheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("body.addEntry")
            }
        }
        .sheet(isPresented: $showEntrySheet) {
            BodyEntryEditorView(entry: editingEntry, initialMetric: selectedMetric)
        }
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(metricOptions, id: \.self) { raw in
                    Button {
                        selectedMetric = raw
                        Haptics.light()
                    } label: {
                        TagChip(text: BodyMetric.displayName(for: raw), tint: Theme.body, isSelected: raw == selectedMetric)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.xs)
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $rangeDays) {
            Text("30d").tag(30)
            Text("90d").tag(90)
            Text("1y").tag(365)
            Text("All").tag(0)
        }
        .pickerStyle(.segmented)
    }

    private var chartCard: some View {
        Card(accent: Theme.body) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(alignment: .lastTextBaseline) {
                    SectionHeader(BodyMetric.displayName(for: selectedMetric))
                    Spacer()
                    if let latest = entries.first {
                        Text("\(Formatting.trimmed(displayValue(latest.value), maxDecimals: 1)) \(unitLabel)")
                            .font(.forgeStat)
                            .foregroundStyle(Theme.body)
                    }
                }
                if rangedEntries.count < 2 {
                    Text("Add at least two entries to see a trend.")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    Chart(rangedEntries.sorted(by: { $0.date < $1.date }), id: \.id) { entry in
                        LineMark(x: .value("Date", entry.date), y: .value("Value", displayValue(entry.value)))
                            .foregroundStyle(Theme.body)
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Date", entry.date), y: .value("Value", displayValue(entry.value)))
                            .foregroundStyle(Theme.body.opacity(0.1).gradient)
                            .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel(unitLabel)
                    .frame(height: 180)
                }
            }
        }
    }

    @ViewBuilder
    private var averagesCard: some View {
        if rangedEntries.count >= 2 {
            let calendar = Calendar.current
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
            let monthStart = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

            let thisWeek = entries.filter { $0.date >= thisWeekStart }.map(\.value)
            let lastWeek = entries.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }.map(\.value)
            let month = entries.filter { $0.date >= monthStart }.map(\.value)

            Card {
                HStack(spacing: Spacing.l) {
                    StatTile(label: "This Week", value: average(thisWeek))
                    StatTile(label: "Last Week", value: average(lastWeek))
                    StatTile(label: "30-Day Avg", value: average(month))
                    if let first = rangedEntries.last, let last = rangedEntries.first {
                        let delta = displayValue(last.value) - displayValue(first.value)
                        StatTile(label: "Range Δ", value: "\(delta >= 0 ? "+" : "")\(Formatting.trimmed(delta, maxDecimals: 1))",
                                 tint: Theme.body)
                    }
                }
            }
        }
    }

    private func average(_ values: [Double]) -> String {
        guard !values.isEmpty else { return "—" }
        let avg = values.reduce(0, +) / Double(values.count)
        return Formatting.trimmed(displayValue(avg), maxDecimals: 1)
    }

    private var entriesList: some View {
        VStack(spacing: Spacing.s) {
            SectionHeader("Entries")
            if entries.isEmpty {
                Card {
                    EmptyStateView(
                        systemImage: "ruler",
                        title: "No entries",
                        message: "Log \(BodyMetric.displayName(for: selectedMetric).lowercased()) to start the chart.",
                        actionTitle: "Add Entry"
                    ) {
                        editingEntry = nil
                        showEntrySheet = true
                    }
                }
            }
            ForEach(entries.prefix(30), id: \.id) { entry in
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Formatting.trimmed(displayValue(entry.value), maxDecimals: 1)) \(unitLabel)")
                                .font(.forgeHeadline)
                                .foregroundStyle(Theme.textPrimary)
                            HStack(spacing: Spacing.xs) {
                                Text(Formatting.mediumDate(entry.date))
                                if entry.source == "healthkit" { Text("· Health") }
                            }
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if !entry.notes.isEmpty {
                            Image(systemName: "note.text")
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .contextMenu {
                    Button("Edit", systemImage: "pencil") {
                        editingEntry = entry
                        showEntrySheet = true
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                }
            }
        }
    }
}

/// Add or edit a single measurement entry.
struct BodyEntryEditorView: View {
    var entry: BodyMeasurementEntry?
    var initialMetric: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var metricRaw = BodyMetric.bodyWeight.rawValue
    @State private var displayValue: Double = 0
    @State private var date = Date()
    @State private var notes = ""
    @State private var newCustomName = ""
    @State private var loaded = false

    private var settings: AppSettings? { settingsList.first }

    private var metricOptions: [String] {
        BodyMetric.allCases.map(\.rawValue) +
        (settings?.customBodyMetrics.map { BodyMetric.customPrefix + $0 } ?? [])
    }

    private var unitLabel: String {
        if let metric = BodyMetric(rawValue: metricRaw) {
            if metric.isMass { return (settings?.weightUnit ?? .kilograms).suffix }
            if metric.isPercent { return "%" }
        }
        return (settings?.lengthUnit ?? .centimeters).suffix
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurement") {
                    Picker("Metric", selection: $metricRaw) {
                        ForEach(metricOptions, id: \.self) {
                            Text(BodyMetric.displayName(for: $0)).tag($0)
                        }
                    }
                    HStack {
                        Text("Value")
                        Spacer()
                        TextField("0", value: $displayValue, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .accessibilityIdentifier("body.value")
                        Text(unitLabel).foregroundStyle(Theme.textSecondary)
                    }
                    DatePicker("Date", selection: $date)
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Custom Metric") {
                    HStack {
                        TextField("New metric name", text: $newCustomName)
                        Button("Add") {
                            let trimmed = newCustomName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty, let settings else { return }
                            if !settings.customBodyMetrics.contains(trimmed) {
                                settings.customBodyMetrics.append(trimmed)
                            }
                            metricRaw = BodyMetric.customPrefix + trimmed
                            newCustomName = ""
                        }
                        .disabled(newCustomName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(entry == nil ? "Add Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(displayValue <= 0)
                        .accessibilityIdentifier("body.save")
                }
            }
            .onAppear { loadIfNeeded() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let entry {
            metricRaw = entry.metricRaw
            displayValue = toDisplay(entry.value, metricRaw: entry.metricRaw)
            date = entry.date
            notes = entry.notes
        } else {
            metricRaw = initialMetric
        }
    }

    private func toDisplay(_ canonical: Double, metricRaw: String) -> Double {
        if let metric = BodyMetric(rawValue: metricRaw) {
            if metric.isMass { return UnitsConverter.displayWeight(kg: canonical, unit: settings?.weightUnit ?? .kilograms) }
            if metric.isPercent { return canonical }
        }
        return UnitsConverter.displayLength(cm: canonical, unit: settings?.lengthUnit ?? .centimeters)
    }

    private func toCanonical(_ display: Double) -> Double {
        if let metric = BodyMetric(rawValue: metricRaw) {
            if metric.isMass { return UnitsConverter.weightKg(fromDisplay: display, unit: settings?.weightUnit ?? .kilograms) }
            if metric.isPercent { return display }
        }
        return UnitsConverter.lengthCm(fromDisplay: display, unit: settings?.lengthUnit ?? .centimeters)
    }

    private func save() {
        if let entry {
            entry.metricRaw = metricRaw
            entry.value = toCanonical(displayValue)
            entry.date = date
            entry.notes = notes
        } else {
            let fresh = BodyMeasurementEntry(date: date, metricRaw: metricRaw, value: toCanonical(displayValue), notes: notes)
            modelContext.insert(fresh)
        }
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
