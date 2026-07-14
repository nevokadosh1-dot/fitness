import SwiftUI
import SwiftData

// MARK: - Apple Health

struct HealthKitSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    @State private var importStatus: String?
    @State private var isImporting = false

    var body: some View {
        Form {
            if !HealthKitService.isAvailable {
                Section {
                    Label("Health data is not available on this device.", systemImage: "heart.slash")
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Section {
                    Toggle("Read from Apple Health", isOn: Binding(
                        get: { settings.healthKitEnabled },
                        set: { enable in
                            if enable {
                                Task {
                                    let granted = await HealthKitService.shared.requestAuthorization()
                                    settings.healthKitEnabled = granted
                                    try? modelContext.save()
                                }
                            } else {
                                settings.healthKitEnabled = false
                            }
                        }
                    ))
                    .tint(Theme.accent)
                } header: {
                    Text("Reading")
                } footer: {
                    Text("Imports running workouts (distance, duration, heart rate, calories) and body weight you record elsewhere. Imported entries are marked \"From Health\" and never duplicate manual logs.")
                }

                if settings.healthKitEnabled {
                    Section("Sync") {
                        Button {
                            runImport()
                        } label: {
                            HStack {
                                Label("Import Now", systemImage: "arrow.down.circle")
                                if isImporting { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(isImporting)
                        if let importStatus {
                            Text(importStatus)
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if let last = settings.lastHealthKitImport {
                            LabeledContent("Last import", value: Formatting.mediumDate(last))
                        }
                    }

                    Section {
                        Toggle("Save strength workouts to Health", isOn: $settings.healthKitWriteWorkouts)
                            .tint(Theme.accent)
                    } header: {
                        Text("Writing")
                    } footer: {
                        Text("When enabled, finished strength workouts are also saved to Apple Health as strength-training workouts. Duration only — sets and weights stay in Forge.")
                    }
                }

                Section {
                    Text("Permissions are managed in the Health app under Sharing → Apps. Denying access never blocks Forge — manual logging always works.")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runImport() {
        isImporting = true
        importStatus = nil
        Task {
            let runCount = await HealthKitService.shared.importRuns(into: modelContext, settings: settings)
            let massCount = await HealthKitService.shared.importBodyMass(into: modelContext)
            importStatus = "Imported \(runCount) run\(runCount == 1 ? "" : "s") and \(massCount) weight entr\(massCount == 1 ? "y" : "ies")."
            isImporting = false
            Haptics.success()
        }
    }
}

// MARK: - Notifications

struct NotificationSettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    @State private var permissionDenied = false

    var body: some View {
        Form {
            if permissionDenied {
                Section {
                    Label("Notifications are turned off in iOS Settings. Enable them there to use reminders.",
                          systemImage: "bell.slash")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Section("Reminders") {
                notifToggle("Scheduled workouts", isOn: $settings.notifyScheduledWorkouts)
                notifToggle("Missed planned sessions", isOn: $settings.notifyMissedSessions)
                notifToggle("Body-weight logging", isOn: $settings.notifyBodyWeightLogging)
                notifToggle("Flexibility sessions", isOn: $settings.notifyFlexibilitySessions)
                notifToggle("Weekly progress review", isOn: $settings.notifyWeeklyReview)
            }
            Section("Times") {
                DatePicker("Workout reminder", selection: minutesBinding($settings.workoutReminderMinutes),
                           displayedComponents: .hourAndMinute)
                DatePicker("Weigh-in reminder", selection: minutesBinding($settings.weighInReminderMinutes),
                           displayedComponents: .hourAndMinute)
            }
            Section {
                Text("All reminders are local notifications generated on your device. Nothing is sent anywhere.")
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            permissionDenied = await NotificationService.authorizationStatus() == .denied
        }
        .onDisappear {
            try? modelContext.save()
            rebuild()
        }
    }

    private func notifToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                if newValue {
                    Task {
                        let granted = await NotificationService.requestPermission()
                        if !granted {
                            isOn.wrappedValue = false
                            permissionDenied = true
                        }
                        rebuild()
                    }
                } else {
                    rebuild()
                }
            }
        ))
        .tint(Theme.accent)
    }

    private func minutesBinding(_ binding: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let start = Calendar.current.startOfDay(for: Date())
                return Calendar.current.date(byAdding: .minute, value: binding.wrappedValue, to: start) ?? start
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                binding.wrappedValue = (components.hour ?? 8) * 60 + (components.minute ?? 0)
            }
        )
    }

    private func rebuild() {
        let week = ScheduleService.resolveWeek(containing: Date(), in: modelContext, settings: settings)
        Task {
            await NotificationService.rebuildSchedule(settings: settings, weekActivities: week.activities)
        }
    }
}

// MARK: - Privacy & App Lock

struct PrivacySettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section {
                Toggle("Require Face ID / passcode", isOn: Binding(
                    get: { settings.appLockEnabled },
                    set: { newValue in
                        if newValue && !AppLockService.isAvailable { return }
                        settings.appLockEnabled = newValue
                    }
                ))
                .tint(Theme.accent)
                .disabled(!AppLockService.isAvailable)
            } header: {
                Text("App Lock")
            } footer: {
                Text(AppLockService.isAvailable
                     ? "When enabled, Forge locks whenever it goes to the background."
                     : "Device authentication is not set up on this device.")
            }

            Section("Your Data") {
                privacyRow("iphone", "Everything is stored locally in Forge's private app storage.")
                privacyRow("icloud", "Optional iCloud sync uses only your personal, private iCloud database (developer setup required — see README).")
                privacyRow("eye.slash", "No analytics, no tracking, no ads, no third-party SDKs.")
                privacyRow("photo", "Progress photos are stored inside the app and never analyzed.")
                privacyRow("heart", "Apple Health is read or written only with your explicit permission.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Privacy & App Lock")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }

    private func privacyRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(text)
                .font(.forgeSubheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 2)
    }
}
