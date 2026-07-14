import SwiftUI
import SwiftData

/// Short first-launch setup: units, priorities, training days, integrations.
/// Every choice can be changed later in Settings; nothing here is mandatory.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var step = 0
    @State private var weightUnit: WeightUnit = .kilograms
    @State private var distanceUnit: DistanceUnit = .kilometers
    @State private var selectedKinds: Set<ActivityKind> = [.strength, .running, .frontSplit, .middleSplit]
    @State private var trainingDays = 5
    @State private var firstWeekday = 2
    @State private var enableHealthKit = false
    @State private var enableNotifications = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar
                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    unitsStep.tag(1)
                    prioritiesStep.tag(2)
                    integrationsStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                footer
            }
        }
        .preferredColorScheme(.dark)
    }

    private var progressBar: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Theme.accent : Theme.surfaceElevated)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.l)
    }

    private var welcomeStep: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("Forge")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Your private fitness operating system.\nStrength, running, splits — everything on your device, nothing shared.")
                .font(.forgeBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Spacing.xl)
    }

    private var unitsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            stepTitle("Units", subtitle: "How you like to measure. Changeable anytime in Settings.")
            Card {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Picker("Weight", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Distance", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Week starts on", selection: $firstWeekday) {
                        Text("Monday").tag(2)
                        Text("Sunday").tag(1)
                        Text("Saturday").tag(7)
                    }
                    .pickerStyle(.segmented)
                }
            }
            Spacer()
        }
        .padding(Spacing.xl)
    }

    private var prioritiesStep: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            stepTitle("Training focus", subtitle: "Pick what you want to track. Everything stays available either way.")
            let kinds: [ActivityKind] = [.strength, .running, .frontSplit, .middleSplit, .mobility]
            VStack(spacing: Spacing.s) {
                ForEach(kinds) { kind in
                    Button {
                        if selectedKinds.contains(kind) {
                            selectedKinds.remove(kind)
                        } else {
                            selectedKinds.insert(kind)
                        }
                        Haptics.light()
                    } label: {
                        HStack {
                            Image(systemName: kind.symbolName)
                                .foregroundStyle(Theme.accent(for: kind))
                                .frame(width: 28)
                            Text(kind.displayName)
                                .font(.forgeHeadline)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: selectedKinds.contains(kind) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedKinds.contains(kind) ? Theme.accent : Theme.textTertiary)
                        }
                        .padding(Spacing.l)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                .fill(Theme.surface)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Card {
                Stepper("Training days per week: \(trainingDays)", value: $trainingDays, in: 1...7)
                    .font(.forgeBody)
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(Spacing.xl)
    }

    private var integrationsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            stepTitle("Integrations", subtitle: "Both optional. Forge works fully offline without them.")
            Card {
                Toggle(isOn: $enableHealthKit) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health").font(.forgeHeadline).foregroundStyle(Theme.textPrimary)
                        Text("Read runs, heart rate and body mass you log elsewhere.")
                            .font(.forgeCaption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .tint(Theme.accent)
            }
            Card {
                Toggle(isOn: $enableNotifications) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reminders").font(.forgeHeadline).foregroundStyle(Theme.textPrimary)
                        Text("Optional nudges for scheduled sessions and weigh-ins.")
                            .font(.forgeCaption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .tint(Theme.accent)
            }
            Text("Your data lives on this device. No accounts, no analytics, no uploads.")
                .font(.forgeCaption)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
        }
        .padding(Spacing.xl)
    }

    private var footer: some View {
        HStack(spacing: Spacing.m) {
            if step > 0 {
                Button("Back") {
                    withAnimation { step -= 1 }
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 100)
            }
            Button(step == totalSteps - 1 ? "Start Training" : "Continue") {
                if step == totalSteps - 1 {
                    finish()
                } else {
                    withAnimation { step += 1 }
                }
                Haptics.medium()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("onboarding.continue")
        }
        .padding(Spacing.xl)
    }

    private func stepTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.forgeTitle).foregroundStyle(Theme.textPrimary)
            Text(subtitle).font(.forgeSubheadline).foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, Spacing.l)
    }

    private func finish() {
        let settings = AppSettings.fetchOrCreate(in: modelContext)
        settings.weightUnit = weightUnit
        settings.distanceUnit = distanceUnit
        settings.firstWeekday = firstWeekday
        settings.onboardingComplete = true
        try? modelContext.save()

        if enableHealthKit {
            Task {
                let granted = await HealthKitService.shared.requestAuthorization()
                if granted { settings.healthKitEnabled = true }
            }
        }
        if enableNotifications {
            Task {
                let granted = await NotificationService.requestPermission()
                if granted {
                    settings.notifyScheduledWorkouts = true
                }
            }
        }
        Haptics.success()
    }
}
