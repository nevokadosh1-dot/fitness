import SwiftUI
import SwiftData

/// Searchable, filterable exercise library with favorites and archive support.
struct ExerciseLibraryView: View {
    /// When set, the view acts as a picker and calls this instead of navigating.
    var onSelect: ((Exercise) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var settingsList: [AppSettings]

    @State private var searchText = ""
    @State private var muscleFilter: String?
    @State private var equipmentFilter: String?
    @State private var categoryFilter: ExerciseCategory?
    @State private var showArchived = false
    @State private var showNewExercise = false

    private var settings: AppSettings? { settingsList.first }

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            if exercise.isArchived != showArchived { return false }
            if let muscleFilter, exercise.primaryMuscleRaw != muscleFilter,
               !exercise.secondaryMusclesRaw.contains(muscleFilter) { return false }
            if let equipmentFilter, exercise.equipmentRaw != equipmentFilter { return false }
            if let categoryFilter, exercise.categoryRaw != categoryFilter.rawValue { return false }
            if !searchText.isEmpty, !exercise.name.localizedCaseInsensitiveContains(searchText) { return false }
            return true
        }
    }

    private var favorites: [Exercise] {
        filtered.filter(\.isFavorite).sorted { $0.favoriteOrder < $1.favoriteOrder }
    }
    private var others: [Exercise] { filtered.filter { !$0.isFavorite } }

    var body: some View {
        List {
            filterBar
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Spacing.s, trailing: 0))
                .listRowSeparator(.hidden)

            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: searchText.isEmpty ? "Nothing here" : "No matches",
                    message: searchText.isEmpty
                        ? (showArchived ? "No archived exercises." : "Add your first exercise to get going.")
                        : "Try a different name or clear the filters.",
                    actionTitle: searchText.isEmpty && !showArchived ? "New Exercise" : nil
                ) { showNewExercise = true }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if !favorites.isEmpty {
                Section {
                    ForEach(favorites, id: \.id) { exercise in
                        row(exercise)
                    }
                    .onMove { source, destination in
                        reorderFavorites(source: source, destination: destination)
                    }
                } header: {
                    Text("Favorites").font(.forgeOverline).foregroundStyle(Theme.textTertiary)
                }
                .listRowBackground(Theme.surface)
            }

            if !others.isEmpty {
                Section {
                    ForEach(others, id: \.id) { exercise in
                        row(exercise)
                    }
                } header: {
                    Text(favorites.isEmpty ? "All Exercises" : "Everything Else")
                        .font(.forgeOverline).foregroundStyle(Theme.textTertiary)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle(onSelect == nil ? "Exercise Library" : "Choose Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewExercise = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("library.newExercise")
            }
        }
        .sheet(isPresented: $showNewExercise) {
            ExerciseEditorView(exercise: nil)
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func row(_ exercise: Exercise) -> some View {
        Group {
            if let onSelect {
                Button {
                    onSelect(exercise)
                } label: {
                    ExerciseRowLabel(exercise: exercise)
                }
            } else {
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    ExerciseRowLabel(exercise: exercise)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                exercise.isFavorite.toggle()
                if exercise.isFavorite {
                    exercise.favoriteOrder = (exercises.filter(\.isFavorite).map(\.favoriteOrder).max() ?? -1) + 1
                }
                try? modelContext.save()
                Haptics.light()
            } label: {
                Label(exercise.isFavorite ? "Unfavorite" : "Favorite",
                      systemImage: exercise.isFavorite ? "star.slash" : "star.fill")
            }
            .tint(Theme.gold)

            Button {
                exercise.isArchived.toggle()
                try? modelContext.save()
            } label: {
                Label(exercise.isArchived ? "Restore" : "Archive", systemImage: "archivebox")
            }
            .tint(Theme.neutral)
        }
    }

    private func reorderFavorites(source: IndexSet, destination: Int) {
        var reordered = favorites
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in reordered.enumerated() {
            exercise.favoriteOrder = index
        }
        try? modelContext.save()
    }

    // MARK: Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                Menu {
                    Button("All Muscles") { muscleFilter = nil }
                    ForEach(settings?.allMuscleGroupOptions ?? MuscleGroup.allCases.map(\.rawValue), id: \.self) { raw in
                        Button(MuscleGroup.displayName(for: raw)) { muscleFilter = raw }
                    }
                } label: {
                    TagChip(text: muscleFilter.map { MuscleGroup.displayName(for: $0) } ?? "Muscle",
                            tint: Theme.accent, isSelected: muscleFilter != nil)
                }

                Menu {
                    Button("All Equipment") { equipmentFilter = nil }
                    ForEach(settings?.allEquipmentOptions ?? EquipmentType.allCases.map(\.rawValue), id: \.self) { raw in
                        Button(EquipmentType.displayName(for: raw)) { equipmentFilter = raw }
                    }
                } label: {
                    TagChip(text: equipmentFilter.map { EquipmentType.displayName(for: $0) } ?? "Equipment",
                            tint: Theme.running, isSelected: equipmentFilter != nil)
                }

                Menu {
                    Button("All Categories") { categoryFilter = nil }
                    ForEach(ExerciseCategory.allCases) { category in
                        Button(category.displayName) { categoryFilter = category }
                    }
                } label: {
                    TagChip(text: categoryFilter?.displayName ?? "Category",
                            tint: Theme.flexibility, isSelected: categoryFilter != nil)
                }

                Button {
                    showArchived.toggle()
                } label: {
                    TagChip(text: "Archived", tint: Theme.neutral, isSelected: showArchived)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.xs)
        }
    }
}

struct ExerciseRowLabel: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: exercise.category.symbolName)
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(exercise.name)
                        .font(.forgeBody)
                        .foregroundStyle(Theme.textPrimary)
                    if exercise.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.gold)
                    }
                }
                Text("\(exercise.primaryMuscleDisplayName) · \(exercise.equipmentDisplayName)")
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
