import SwiftUI
import SwiftData

/// Completion flow: date, rating, wellness scores and final notes.
struct FinishWorkoutSheet: View {
    @Bindable var session: WorkoutSession
    var onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var completedAt = Date()
    @State private var rating: Int?
    @State private var energy: Int?
    @State private var soreness: Int?
    @State private var finalNotes = ""
    @State private var loaded = false

    private var settings: AppSettings? { settingsList.first }
    private var incompleteSets: Int {
        (session.exercises ?? []).flatMap { $0.sets ?? [] }.filter { !$0.isCompleted }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    summaryCard

                    Card {
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            SectionHeader("Session Rating")
                            HStack(spacing: Spacing.s) {
                                ForEach(1...5, id: \.self) { star in
                                    Button {
                                        rating = (rating == star) ? nil : star
                                        Haptics.light()
                                    } label: {
                                        Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                                            .font(.title2)
                                            .foregroundStyle(star <= (rating ?? 0) ? Theme.gold : Theme.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            ScaleSelector(label: "Energy", value: $energy)
                            ScaleSelector(label: "Soreness", value: $soreness, tint: Theme.body)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            SectionHeader("Completion Date")
                            DatePicker("Completed", selection: $completedAt)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(Theme.accent)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            SectionHeader("Final Notes")
                            TextField("Anything worth remembering?", text: $finalNotes, axis: .vertical)
                                .font(.forgeBody)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2...6)
                        }
                    }

                    if incompleteSets > 0 {
                        Text("\(incompleteSets) unchecked set\(incompleteSets == 1 ? "" : "s") will be kept but won't count toward volume or records.")
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        finish()
                    } label: {
                        Label("Save Workout", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("workout.saveFinish")
                }
                .padding(Spacing.l)
            }
            .background(Theme.background)
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                finalNotes = session.notes
                rating = session.rating
                energy = session.energy
                soreness = session.soreness
            }
        }
        .preferredColorScheme(.dark)
    }

    private var summaryCard: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(session.name.isEmpty ? "Workout" : session.name)
                    .font(.forgeTitle)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: Spacing.l) {
                    StatTile(label: "Duration", value: Formatting.workoutDuration(session.duration))
                    StatTile(label: "Volume", value: Formatting.volume(session.totalVolumeKg, unit: settings?.weightUnit ?? .kilograms), tint: Theme.accent)
                    StatTile(label: "Hard Sets", value: "\(session.hardSetCount)")
                    if let rpe = session.averageRPE {
                        StatTile(label: "Avg RPE", value: String(format: "%.1f", rpe))
                    }
                }
            }
        }
    }

    private func finish() {
        guard let settings else { return }
        session.rating = rating
        session.energy = energy
        session.soreness = soreness
        session.notes = finalNotes
        WorkoutService.finish(session, in: modelContext, settings: settings, completedAt: completedAt)
        if settings.healthKitEnabled && settings.healthKitWriteWorkouts {
            let finished = session
            Task { await HealthKitService.shared.saveStrengthWorkout(finished) }
        }
        Haptics.success()
        dismiss()
        onFinished()
    }
}
