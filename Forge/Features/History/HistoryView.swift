import SwiftUI
import SwiftData

/// Workout history: switchable list / calendar, search and muscle filter.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    @Query private var settingsList: [AppSettings]

    @State private var mode: Mode = .list
    @State private var searchText = ""
    @State private var muscleFilter: String?
    @State private var calendarMonth = Date()

    enum Mode: String, CaseIterable { case list = "List", calendar = "Calendar" }

    private var settings: AppSettings? { settingsList.first }

    private var completed: [WorkoutSession] {
        allSessions.filter { $0.status == .completed }
    }

    private var filtered: [WorkoutSession] {
        completed.filter { session in
            if !searchText.isEmpty {
                let inName = session.name.localizedCaseInsensitiveContains(searchText)
                let inExercise = (session.exercises ?? []).contains {
                    $0.displayName.localizedCaseInsensitiveContains(searchText)
                }
                if !inName && !inExercise { return false }
            }
            if let muscleFilter {
                let hasMuscle = (session.exercises ?? []).contains {
                    $0.primaryMuscleSnapshot == muscleFilter || $0.secondaryMusclesSnapshot.contains(muscleFilter)
                }
                if !hasMuscle { return false }
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.s)

            switch mode {
            case .list: listBody
            case .calendar: calendarBody
            }
        }
        .background(Theme.background)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: List

    private var listBody: some View {
        List {
            muscleFilterBar
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))

            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: completed.isEmpty ? "No workouts yet" : "No matches",
                    message: completed.isEmpty
                        ? "Finished workouts appear here with volume, sets and records."
                        : "Try different search terms or clear the filter."
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(filtered, id: \.id) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    sessionRow(session)
                }
                .listRowBackground(Theme.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Search workouts or exercises")
    }

    private var muscleFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                Button {
                    muscleFilter = nil
                } label: {
                    TagChip(text: "All", tint: Theme.accent, isSelected: muscleFilter == nil)
                }
                .buttonStyle(.plain)
                ForEach(MuscleGroup.allCases) { group in
                    Button {
                        muscleFilter = muscleFilter == group.rawValue ? nil : group.rawValue
                    } label: {
                        TagChip(text: group.displayName, tint: Theme.accent, isSelected: muscleFilter == group.rawValue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(session.name.isEmpty ? "Workout" : session.name)
                    .font(.forgeHeadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(Formatting.mediumDate(session.completedAt ?? session.startedAt))
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: Spacing.m) {
                Label(Formatting.workoutDuration(session.duration), systemImage: "clock")
                Label(Formatting.volume(session.totalVolumeKg, unit: settings?.weightUnit ?? .kilograms), systemImage: "scalemass")
                Label("\(session.hardSetCount) sets", systemImage: "checkmark.circle")
            }
            .font(.forgeCaption)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: Calendar

    private var calendarBody: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                monthHeader
                MonthGrid(
                    month: calendarMonth,
                    firstWeekday: settings?.firstWeekday ?? 2,
                    markedDates: Set(completed.map { Calendar.current.startOfDay(for: $0.completedAt ?? $0.startedAt) })
                ) { day in
                    daySessionList(for: day)
                }
            }
            .padding(Spacing.l)
        }
    }

    private var monthHeader: some View {
        HStack {
            IconButton(systemImage: "chevron.left") {
                calendarMonth = Calendar.current.date(byAdding: .month, value: -1, to: calendarMonth) ?? calendarMonth
            }
            Spacer()
            Text(calendarMonth.formatted(.dateTime.month(.wide).year()))
                .font(.forgeHeadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            IconButton(systemImage: "chevron.right") {
                calendarMonth = Calendar.current.date(byAdding: .month, value: 1, to: calendarMonth) ?? calendarMonth
            }
        }
    }

    @ViewBuilder
    private func daySessionList(for day: Date) -> some View {
        let sessions = completed.filter {
            Calendar.current.isDate($0.completedAt ?? $0.startedAt, inSameDayAs: day)
        }
        if sessions.isEmpty {
            Card {
                Text("No workouts on \(Formatting.mediumDate(day))")
                    .font(.forgeSubheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            ForEach(sessions, id: \.id) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    Card(accent: Theme.accent) { sessionRow(session) }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Month calendar grid with dots on training days and a tappable selection.
struct MonthGrid<DayDetail: View>: View {
    var month: Date
    var firstWeekday: Int
    var markedDates: Set<Date>
    @ViewBuilder var dayDetail: (Date) -> DayDetail

    @State private var selectedDay: Date?

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            let days = monthDays()
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.forgeOverline)
                        .foregroundStyle(Theme.textTertiary)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
            if let selectedDay {
                dayDetail(selectedDay)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isMarked = markedDates.contains(calendar.startOfDay(for: day))
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)
        return Button {
            selectedDay = day
            Haptics.light()
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.forgeSubheadline)
                    .foregroundStyle(isSelected ? Color.black : (isToday ? Theme.accent : Theme.textPrimary))
                Circle()
                    .fill(isMarked ? (isSelected ? Color.black : Theme.accent) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// Days of the month padded with nils to align the first weekday.
    private func monthDays() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayCount = calendar.range(of: .day, in: .month, for: month)?.count
        else { return [] }
        let firstDay = interval.start
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (weekdayOfFirst - firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        return cells
    }
}
