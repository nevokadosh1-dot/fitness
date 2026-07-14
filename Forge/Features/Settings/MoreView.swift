import SwiftUI
import SwiftData

/// The More tab: settings, integrations, data management and privacy.
struct MoreView: View {
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            List {
                if let settings {
                    Section("Preferences") {
                        NavigationLink { UnitsSettingsView(settings: settings) } label: {
                            Label("Units & Defaults", systemImage: "ruler")
                        }
                        NavigationLink { DashboardSettingsView(settings: settings) } label: {
                            Label("Dashboard Cards", systemImage: "rectangle.grid.1x2")
                        }
                        NavigationLink { RunningGoalSettingsView(settings: settings) } label: {
                            Label("Running Goal", systemImage: "figure.run")
                        }
                        NavigationLink { CustomizationSettingsView(settings: settings) } label: {
                            Label("Custom Options", systemImage: "slider.horizontal.3")
                        }
                        NavigationLink { AppearanceSettingsView(settings: settings) } label: {
                            Label("Appearance & Haptics", systemImage: "paintbrush")
                        }
                    }

                    Section("Integrations") {
                        NavigationLink { HealthKitSettingsView(settings: settings) } label: {
                            Label("Apple Health", systemImage: "heart.fill")
                        }
                        NavigationLink { NotificationSettingsView(settings: settings) } label: {
                            Label("Notifications", systemImage: "bell.badge")
                        }
                    }

                    Section("Privacy & Data") {
                        NavigationLink { PrivacySettingsView(settings: settings) } label: {
                            Label("Privacy & App Lock", systemImage: "lock.shield")
                        }
                        NavigationLink { DataManagementView() } label: {
                            Label("Backup, Export & Restore", systemImage: "externaldrive")
                        }
                    }
                }

                Section("About") {
                    NavigationLink { AboutView() } label: {
                        Label("About Forge", systemImage: "info.circle")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .listRowBackground(Theme.surface)
            .navigationTitle("More")
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
    }
}

// MARK: - Units & defaults

struct UnitsSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section("Units") {
                Picker("Weight", selection: Binding(get: { settings.weightUnit }, set: { settings.weightUnit = $0 })) {
                    ForEach(WeightUnit.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Distance", selection: Binding(get: { settings.distanceUnit }, set: { settings.distanceUnit = $0 })) {
                    ForEach(DistanceUnit.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Lengths", selection: Binding(get: { settings.lengthUnit }, set: { settings.lengthUnit = $0 })) {
                    ForEach(LengthUnit.allCases) { Text($0.displayName).tag($0) }
                }
            }
            Section("Training Defaults") {
                HStack {
                    Text("Default weight increment")
                    Spacer()
                    TextField("2.5", value: $settings.defaultIncrementKg, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("kg").foregroundStyle(Theme.textSecondary)
                }
                Toggle("Show RPE fields", isOn: $settings.showRPE).tint(Theme.accent)
                Picker("Week starts on", selection: $settings.firstWeekday) {
                    Text("Monday").tag(2)
                    Text("Sunday").tag(1)
                    Text("Saturday").tag(7)
                }
            }
            Section {
                Text("Values are always stored in metric internally, so switching units never changes your data.")
                    .font(.forgeCaption).foregroundStyle(Theme.textTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Units & Defaults")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }
}

// MARK: - Dashboard cards

struct DashboardSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section {
                ForEach(settings.dashboardCards) { card in
                    HStack {
                        Text(card.displayName).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .onMove { source, destination in
                    var cards = settings.dashboardCards
                    cards.move(fromOffsets: source, toOffset: destination)
                    settings.dashboardCards = cards
                }
                .onDelete { offsets in
                    var cards = settings.dashboardCards
                    cards.remove(atOffsets: offsets)
                    settings.dashboardCards = cards
                }
            } header: {
                Text("Visible cards — drag to reorder, swipe to hide")
            }
            .listRowBackground(Theme.surface)

            let hidden = DashboardCard.allCases.filter { !settings.dashboardCards.contains($0) }
            if !hidden.isEmpty {
                Section("Hidden") {
                    ForEach(hidden) { card in
                        Button {
                            settings.dashboardCards.append(card)
                        } label: {
                            Label(card.displayName, systemImage: "plus.circle")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Dashboard Cards")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }
}

// MARK: - Running goal

struct RunningGoalSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    @State private var goalSeconds: Double = 0

    var body: some View {
        Form {
            Section("Goal") {
                TextField("Label (e.g. Sub-14 3K)", text: $settings.runningGoalLabel)
                Picker("Distance", selection: $settings.runningGoalDistanceMeters) {
                    ForEach(BenchmarkDistance.allCases) { benchmark in
                        Text(benchmark.displayName).tag(benchmark.meters)
                    }
                }
                DurationField(label: "Target time", totalSeconds: $goalSeconds)
            }
            Section {
                Button("Clear Goal", role: .destructive) {
                    settings.runningGoalLabel = ""
                    settings.runningGoalSeconds = 0
                    goalSeconds = 0
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Running Goal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { goalSeconds = settings.runningGoalSeconds }
        .onDisappear {
            settings.runningGoalSeconds = goalSeconds
            try? modelContext.save()
        }
    }
}

// MARK: - Customization catalogs

struct CustomizationSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            catalogSection("Muscle Groups", items: $settings.customMuscleGroups)
            catalogSection("Equipment", items: $settings.customEquipment)
            catalogSection("Run Types", items: $settings.customRunTypes)
            catalogSection("Stretch Areas", items: $settings.customStretchAreas)
            catalogSection("Body Metrics", items: $settings.customBodyMetrics)
            catalogSection("Activity Types", items: $settings.customActivityKinds)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Custom Options")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }

    private func catalogSection(_ title: String, items: Binding<[String]>) -> some View {
        Section(title) {
            ForEach(items.wrappedValue, id: \.self) { item in
                Text(item).foregroundStyle(Theme.textPrimary)
            }
            .onDelete { offsets in
                items.wrappedValue.remove(atOffsets: offsets)
            }
            CatalogAddRow { newValue in
                if !items.wrappedValue.contains(newValue) {
                    items.wrappedValue.append(newValue)
                }
            }
        }
        .listRowBackground(Theme.surface)
    }
}

private struct CatalogAddRow: View {
    var onAdd: (String) -> Void
    @State private var text = ""

    var body: some View {
        HStack {
            TextField("Add option", text: $text)
            Button("Add") {
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                onAdd(trimmed)
                text = ""
                Haptics.light()
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section("Feel") {
                Toggle("Haptic feedback", isOn: Binding(
                    get: { settings.hapticsEnabled },
                    set: { newValue in
                        settings.hapticsEnabled = newValue
                        Haptics.isEnabled = newValue
                    }
                ))
                .tint(Theme.accent)
            }
            Section {
                Text("Forge is designed dark-first for the gym. Dynamic Type is fully supported — adjust text size in iOS Settings.")
                    .font(.forgeCaption).foregroundStyle(Theme.textTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Appearance & Haptics")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, Spacing.xxl)
                Text("Forge")
                    .font(.forgeHero)
                    .foregroundStyle(Theme.textPrimary)
                Text("A private, offline-first fitness operating system.\nStrength · Running · Flexibility")
                    .font(.forgeSubheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Card {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        SectionHeader("Privacy")
                        Text("Everything you log stays in this app's private storage on your device (and your personal iCloud, if you enable sync in Xcode). There are no accounts, no analytics, no ads and no third-party services. Estimated values such as 1RM and race projections are informational estimates, not medical or coaching advice.")
                            .font(.forgeSubheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, Spacing.l)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
