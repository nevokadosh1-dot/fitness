import SwiftUI
import SwiftData

/// The Train tab: strength templates, running, flexibility, library and history.
struct WorkoutsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]
    @Query private var settingsList: [AppSettings]

    @State private var liveSession: WorkoutSession?
    @State private var showNewTemplate = false
    @State private var showArchivedTemplates = false

    private var settings: AppSettings? { settingsList.first }
    private var activeTemplates: [WorkoutTemplate] { templates.filter { !$0.isArchived } }
    private var archivedTemplates: [WorkoutTemplate] { templates.filter(\.isArchived) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    quickStart
                    templatesSection
                    modulesSection
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Theme.background)
            .scrollIndicators(.hidden)
            .navigationTitle("Train")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewTemplate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("train.newTemplate")
                }
            }
            .fullScreenCover(item: $liveSession) { session in
                LiveWorkoutView(session: session)
            }
            .sheet(isPresented: $showNewTemplate) {
                TemplateEditorView(template: nil)
            }
        }
    }

    // MARK: Quick start

    private var quickStart: some View {
        VStack(spacing: Spacing.s) {
            if let active = StoreQueries.activeSession(in: modelContext) {
                Button {
                    liveSession = active
                } label: {
                    HStack {
                        Image(systemName: "bolt.circle.fill")
                        Text("Resume \(active.name.isEmpty ? "Workout" : active.name)")
                        Spacer()
                        Text(Formatting.workoutDuration(active.duration))
                            .font(.forgeCaption)
                    }
                    .font(.forgeHeadline)
                    .foregroundStyle(Color.black)
                    .padding(Spacing.l)
                    .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Theme.accent))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    guard let settings else { return }
                    Haptics.medium()
                    liveSession = WorkoutService.startSession(template: nil, name: "Workout", in: modelContext, settings: settings)
                } label: {
                    Label("Start Empty Workout", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("train.startEmpty")
            }
        }
    }

    // MARK: Templates

    private var templatesSection: some View {
        VStack(spacing: Spacing.s) {
            SectionHeader("Workout Templates")
            if activeTemplates.isEmpty {
                Card {
                    EmptyStateView(
                        systemImage: "square.grid.2x2",
                        title: "No templates yet",
                        message: "Templates let you start a planned workout in one tap.",
                        actionTitle: "Create Template"
                    ) { showNewTemplate = true }
                }
            } else {
                ForEach(activeTemplates, id: \.id) { template in
                    templateRow(template)
                }
            }
            if !archivedTemplates.isEmpty {
                DisclosureGroup(isExpanded: $showArchivedTemplates) {
                    ForEach(archivedTemplates, id: \.id) { template in
                        templateRow(template)
                    }
                } label: {
                    Text("Archived (\(archivedTemplates.count))")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, Spacing.xs)
            }
        }
    }

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        NavigationLink {
            TemplateDetailView(template: template)
        } label: {
            Card(accent: Color(hex: template.colorHex)) {
                HStack(spacing: Spacing.m) {
                    Image(systemName: template.iconName)
                        .font(.title3)
                        .foregroundStyle(Color(hex: template.colorHex))
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .font(.forgeHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(templateSubtitle(template))
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button("Start") {
                        guard let settings else { return }
                        Haptics.medium()
                        liveSession = WorkoutService.startSession(template: template, name: template.name, in: modelContext, settings: settings)
                    }
                    .buttonStyle(PillButtonStyle(tint: Color(hex: template.colorHex), filled: true))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func templateSubtitle(_ template: WorkoutTemplate) -> String {
        var parts = ["\(template.exerciseCount) exercises", "\(template.totalPlannedSets) sets"]
        if let minutes = template.estimatedMinutes { parts.append("~\(minutes) min") }
        return parts.joined(separator: " · ")
    }

    // MARK: Modules

    private var modulesSection: some View {
        VStack(spacing: Spacing.s) {
            SectionHeader("Modules")
            moduleLink(title: "Running", subtitle: "Log runs, splits and time trials", icon: "figure.run", tint: Theme.running, identifier: "train.module.running") {
                RunningHomeView()
            }
            moduleLink(title: "Flexibility", subtitle: "Splits, stretching and mobility", icon: "figure.flexibility", tint: Theme.flexibility, identifier: "train.module.flexibility") {
                FlexibilityHomeView()
            }
            moduleLink(title: "Exercise Library", subtitle: "Browse, edit and create exercises", icon: "books.vertical.fill", tint: Theme.accent, identifier: "train.module.library") {
                ExerciseLibraryView()
            }
            moduleLink(title: "History", subtitle: "Every logged session, searchable", icon: "clock.arrow.circlepath", tint: Theme.gold, identifier: "train.module.history") {
                HistoryView()
            }
        }
    }

    private func moduleLink<Destination: View>(
        title: String, subtitle: String, icon: String, tint: Color, identifier: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Card {
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
}
