import SwiftUI
import SwiftData

/// The Progress tab: analytics, records, insights, body and photos.
struct ProgressHomeView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var recentPRs: [PersonalRecord] = []
    @State private var pendingInsights = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    NavigationLink {
                        AnalyticsView()
                    } label: {
                        HeroCard {
                            HStack(spacing: Spacing.m) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title2)
                                    .foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Analytics")
                                        .font(.forgeHeadline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Strength, volume, running and flexibility trends")
                                        .font(.forgeCaption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    sectionLink(title: "Personal Records", subtitle: recordsSubtitle,
                                icon: "trophy.fill", tint: Theme.gold, identifier: "progress.records") {
                        PersonalRecordsView()
                    }
                    sectionLink(title: "Insights", subtitle: insightsSubtitle,
                                icon: "lightbulb.fill", tint: Theme.accent, identifier: "progress.insights") {
                        InsightsView()
                    }
                    sectionLink(title: "Body Measurements", subtitle: "Weight, girths and custom metrics",
                                icon: "figure.arms.open", tint: Theme.body, identifier: "progress.body") {
                        BodyMeasurementsView()
                    }
                    sectionLink(title: "Progress Photos", subtitle: "Private gallery with compare mode",
                                icon: "photo.on.rectangle.angled", tint: Theme.flexibility, identifier: "progress.photos") {
                        ProgressPhotosView()
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Theme.background)
            .scrollIndicators(.hidden)
            .navigationTitle("Progress")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .task { refresh() }
        }
    }

    private var recordsSubtitle: String {
        recentPRs.isEmpty ? "Records appear as you train" : "\(recentPRs.count) new in the last 30 days"
    }

    private var insightsSubtitle: String {
        pendingInsights == 0 ? "Data-driven observations about your training"
                             : "\(pendingInsights) active suggestions"
    }

    private func sectionLink<Destination: View>(
        title: String, subtitle: String, icon: String, tint: Color, identifier: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Card(accent: tint) {
                HStack(spacing: Spacing.m) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(tint)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.forgeHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(subtitle)
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func refresh() {
        recentPRs = PRService.recent(in: modelContext, days: 30)
        let insights = (try? modelContext.fetch(FetchDescriptor<Insight>())) ?? []
        pendingInsights = insights.filter { !$0.isDismissed }.count
    }
}
