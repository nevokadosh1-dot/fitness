import SwiftUI
import SwiftData

/// Rule-based training insights with visible evidence, dismissal, and
/// per-category toggles. Everything is computed locally from stored data.
struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    @State private var insights: [Insight] = []
    @State private var showDismissed = false
    @State private var showCategorySettings = false

    private var settings: AppSettings? { settingsList.first }
    private var visible: [Insight] {
        insights.filter { showDismissed || !$0.isDismissed }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                disclaimer
                if visible.isEmpty {
                    EmptyStateView(
                        systemImage: "lightbulb",
                        title: "No insights right now",
                        message: "As you log more training, Forge looks for patterns worth mentioning — overload opportunities, stalls, high fatigue, missed sessions and more."
                    )
                }
                ForEach(visible, id: \.id) { insight in
                    InsightCard(insight: insight) {
                        insight.isDismissed.toggle()
                        try? modelContext.save()
                        Haptics.light()
                    }
                }
                if insights.contains(where: \.isDismissed) {
                    Button(showDismissed ? "Hide dismissed" : "Show dismissed") {
                        showDismissed.toggle()
                    }
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCategorySettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Insight categories")
            }
        }
        .sheet(isPresented: $showCategorySettings, onDismiss: { refresh() }) {
            InsightCategorySettingsView()
        }
        .task { refresh() }
    }

    private var disclaimer: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Theme.textTertiary)
            Text("Observations from your own logs — not medical advice, diagnoses or guarantees. Each insight shows the data behind it.")
                .font(.forgeCaption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Theme.surface))
    }

    private func refresh() {
        guard let settings else { return }
        insights = InsightsService.refresh(in: modelContext, settings: settings)
    }
}

struct InsightCard: View {
    let insight: Insight
    var onToggleDismiss: () -> Void

    @State private var showEvidence = false

    var body: some View {
        Card(accent: insight.isDismissed ? Theme.neutral : Theme.accent) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(alignment: .top, spacing: Spacing.m) {
                    Image(systemName: insight.category.symbolName)
                        .font(.title3)
                        .foregroundStyle(insight.isDismissed ? Theme.textTertiary : Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.category.displayName)
                            .font(.forgeOverline)
                            .foregroundStyle(Theme.textTertiary)
                        Text(insight.title)
                            .font(.forgeHeadline)
                            .foregroundStyle(insight.isDismissed ? Theme.textSecondary : Theme.textPrimary)
                    }
                    Spacer()
                    Button {
                        onToggleDismiss()
                    } label: {
                        Image(systemName: insight.isDismissed ? "arrow.uturn.backward.circle" : "xmark.circle")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(insight.isDismissed ? "Restore insight" : "Dismiss insight")
                }
                Text(insight.body)
                    .font(.forgeSubheadline)
                    .foregroundStyle(Theme.textSecondary)

                if !insight.evidence.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showEvidence.toggle() }
                    } label: {
                        Label(showEvidence ? "Hide evidence" : "Why am I seeing this?",
                              systemImage: showEvidence ? "chevron.up" : "chevron.down")
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    if showEvidence {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(insight.evidence, id: \.self) { line in
                                HStack(alignment: .top, spacing: Spacing.xs) {
                                    Circle()
                                        .fill(Theme.textTertiary)
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 6)
                                    Text(line)
                                        .font(.forgeCaption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                        }
                        .padding(Spacing.m)
                        .background(RoundedRectangle(cornerRadius: Radius.s, style: .continuous).fill(Theme.surfaceElevated))
                    }
                }
            }
        }
    }
}

/// Turn insight categories on or off.
struct InsightCategorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(InsightCategory.allCases) { category in
                        Toggle(isOn: binding(for: category)) {
                            Label(category.displayName, systemImage: category.symbolName)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .tint(Theme.accent)
                    }
                } footer: {
                    Text("Disabled categories are removed on the next refresh and never generated again until re-enabled.")
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Insight Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func binding(for category: InsightCategory) -> Binding<Bool> {
        Binding(
            get: { settings?.isInsightCategoryEnabled(category) ?? true },
            set: { enabled in
                guard let settings else { return }
                if enabled {
                    settings.disabledInsightCategories.removeAll { $0 == category.rawValue }
                } else if !settings.disabledInsightCategories.contains(category.rawValue) {
                    settings.disabledInsightCategories.append(category.rawValue)
                }
            }
        )
    }
}
