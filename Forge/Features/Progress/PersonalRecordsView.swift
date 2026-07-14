import SwiftUI
import SwiftData

/// All personal records, grouped by area, recomputed from raw history.
struct PersonalRecordsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var records: [PersonalRecord] = []

    private var strengthRecords: [PersonalRecord] {
        records.filter { [.heaviestWeight, .repsAtWeight, .estimatedOneRM, .sessionVolume].contains($0.kind) }
            .sorted { ($0.subject, $0.kindRaw) < ($1.subject, $1.kindRaw) }
    }
    private var runningRecords: [PersonalRecord] {
        records.filter { [.fastestTime, .bestPace, .longestRun].contains($0.kind) }
            .sorted { $0.subject < $1.subject }
    }
    private var flexibilityRecords: [PersonalRecord] {
        records.filter { [.bestFrontSplitLeft, .bestFrontSplitRight, .bestMiddleSplit].contains($0.kind) }
    }
    private var streakRecords: [PersonalRecord] {
        records.filter { $0.kind == .longestStreak }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if records.isEmpty {
                    EmptyStateView(
                        systemImage: "trophy",
                        title: "No records yet",
                        message: "Finish workouts, log runs and track split measurements — records are detected automatically."
                    )
                } else {
                    if !streakRecords.isEmpty {
                        recordGroup("Consistency", records: streakRecords, tint: Theme.gold)
                    }
                    if !strengthRecords.isEmpty {
                        recordGroup("Strength", records: strengthRecords, tint: Theme.accent)
                    }
                    if !runningRecords.isEmpty {
                        recordGroup("Running", records: runningRecords, tint: Theme.running)
                    }
                    if !flexibilityRecords.isEmpty {
                        recordGroup("Flexibility", records: flexibilityRecords, tint: Theme.flexibility)
                    }
                    Text("Estimated values (like 1RM) are calculated from your logs and are estimates, not tested maxes. Records update automatically when you edit past sessions.")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, Spacing.s)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            records = PRService.recompute(in: modelContext)
        }
    }

    private func recordGroup(_ title: String, records: [PersonalRecord], tint: Color) -> some View {
        VStack(spacing: Spacing.s) {
            SectionHeader(title)
            ForEach(records, id: \.id) { record in
                Card(accent: tint) {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.subject)
                                .font(.forgeHeadline)
                                .foregroundStyle(Theme.textPrimary)
                            Text(record.kind.displayName)
                                .font(.forgeOverline)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(record.detail)
                                .font(.forgeSubheadline)
                                .foregroundStyle(tint)
                            Text(Formatting.mediumDate(record.date))
                                .font(.forgeCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }
}
