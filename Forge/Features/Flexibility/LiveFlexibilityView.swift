import SwiftUI
import SwiftData
import Combine

/// A guided flexibility session: one step per set (and side), with hold and
/// rest timers, skip/back controls, and a completion summary.
struct LiveFlexibilityView: View {
    let routine: FlexibilityRoutine

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    struct Step: Identifiable, Equatable {
        let id = UUID()
        var itemIndex: Int
        var name: String
        var instructions: String
        var holdSeconds: Int
        var restSeconds: Int
        var setNumber: Int
        var totalSets: Int
        var side: String?
    }

    private enum Phase: Equatable {
        case hold, rest, finished
    }

    @State private var steps: [Step] = []
    @State private var stepIndex = 0
    @State private var phase: Phase = .hold
    @State private var remaining = 0
    @State private var isPaused = false
    @State private var startedAt = Date()
    @State private var completedStepIDs: Set<UUID> = []
    @State private var skippedItemIndices: Set<Int> = []
    @State private var showExitConfirm = false
    @State private var intensity: Int?
    @State private var notes = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if phase == .finished {
                    summaryView
                } else if let step = currentStep {
                    sessionView(step)
                } else {
                    // Routine had no items; nothing to run.
                    EmptyStateView(
                        systemImage: "figure.flexibility",
                        title: "Empty routine",
                        message: "Add stretches to this routine first.",
                        actionTitle: "Close"
                    ) { dismiss() }
                }
            }
            .navigationTitle(routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if phase == .finished { dismiss() } else { showExitConfirm = true }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .confirmationDialog("Leave this session?", isPresented: $showExitConfirm, titleVisibility: .visible) {
                Button("Save Progress & Finish") { finishEarly() }
                Button("Discard Session", role: .destructive) { dismiss() }
                Button("Keep Stretching", role: .cancel) {}
            }
            .onAppear { buildSteps() }
            .onReceive(timer) { _ in tick() }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private var currentStep: Step? {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    }

    // MARK: Session UI

    private func sessionView(_ step: Step) -> some View {
        VStack(spacing: Spacing.l) {
            // Progress
            HStack(spacing: 4) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < stepIndex ? Theme.flexibility : (index == stepIndex ? Theme.flexibility.opacity(0.8) : Theme.surfaceElevated))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, Spacing.l)

            Spacer()

            VStack(spacing: Spacing.s) {
                if let side = step.side {
                    TagChip(text: "\(side) side", tint: Theme.flexibility, isSelected: true)
                }
                Text(step.name)
                    .font(.forgeTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Set \(step.setNumber) of \(step.totalSets)")
                    .font(.forgeCaption)
                    .foregroundStyle(Theme.textSecondary)
            }

            // Timer ring
            ZStack {
                let total = phase == .hold ? step.holdSeconds : step.restSeconds
                Circle()
                    .stroke(Theme.surfaceElevated, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: total > 0 ? CGFloat(remaining) / CGFloat(total) : 0)
                    .stroke(phase == .hold ? Theme.flexibility : Theme.running,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                VStack(spacing: 2) {
                    Text("\(remaining)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text(phase == .hold ? "HOLD" : "REST")
                        .font(.forgeOverline)
                        .tracking(2)
                        .foregroundStyle(phase == .hold ? Theme.flexibility : Theme.running)
                }
            }
            .frame(width: 220, height: 220)
            .padding(.vertical, Spacing.m)

            if !step.instructions.isEmpty {
                Text(step.instructions)
                    .font(.forgeSubheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .lineLimit(4)
            }

            Spacer()

            controls
        }
        .padding(.vertical, Spacing.l)
    }

    private var controls: some View {
        HStack(spacing: Spacing.l) {
            IconButton(systemImage: "backward.end.fill", tint: Theme.textSecondary, size: 52) {
                previousStep()
            }
            .accessibilityLabel("Previous stretch")

            Button {
                isPaused.toggle()
                Haptics.light()
            } label: {
                Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.flexibility)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPaused ? "Resume" : "Pause")

            IconButton(systemImage: "forward.end.fill", tint: Theme.textSecondary, size: 52) {
                skipStep()
            }
            .accessibilityLabel("Skip stretch")
        }
        .padding(.bottom, Spacing.l)
    }

    // MARK: Summary

    private var summaryView: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.flexibility)
                    .padding(.top, Spacing.xxl)
                Text("Session Complete")
                    .font(.forgeTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(completedStepIDs.count) of \(steps.count) holds · \(Formatting.workoutDuration(Date().timeIntervalSince(startedAt)))")
                    .font(.forgeSubheadline)
                    .foregroundStyle(Theme.textSecondary)

                Card {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        ScaleSelector(label: "Discomfort / Intensity", value: $intensity, tint: Theme.flexibility)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("NOTES")
                                .font(.forgeOverline)
                                .tracking(0.8)
                                .foregroundStyle(Theme.textTertiary)
                            TextField("How did it feel?", text: $notes, axis: .vertical)
                                .font(.forgeBody)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2...5)
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)

                Button {
                    saveSession()
                } label: {
                    Label("Save Session", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.flexibility))
                .padding(.horizontal, Spacing.l)
                .accessibilityIdentifier("flex.saveSession")
            }
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: State machine

    private func buildSteps() {
        guard steps.isEmpty else { return }
        var built: [Step] = []
        for (itemIndex, item) in routine.orderedItems.enumerated() {
            let sides: [String?] = item.sideMode == .leftRight ? ["Left", "Right"] : [nil]
            for setNumber in 1...max(1, item.sets) {
                for side in sides {
                    built.append(Step(
                        itemIndex: itemIndex,
                        name: item.displayName,
                        instructions: item.displayInstructions,
                        holdSeconds: max(5, item.holdSeconds),
                        restSeconds: item.restSeconds,
                        setNumber: setNumber,
                        totalSets: max(1, item.sets),
                        side: side
                    ))
                }
            }
        }
        steps = built
        startedAt = Date()
        if let first = built.first {
            remaining = first.holdSeconds
            phase = .hold
        } else {
            phase = .finished
        }
    }

    private func tick() {
        guard !isPaused, phase != .finished, currentStep != nil else { return }
        guard remaining > 1 else {
            advancePhase()
            return
        }
        remaining -= 1
    }

    private func advancePhase() {
        guard let step = currentStep else { return }
        switch phase {
        case .hold:
            completedStepIDs.insert(step.id)
            Haptics.success()
            if step.restSeconds > 0 && stepIndex < steps.count - 1 {
                phase = .rest
                remaining = step.restSeconds
            } else {
                moveToStep(stepIndex + 1)
            }
        case .rest:
            moveToStep(stepIndex + 1)
        case .finished:
            break
        }
    }

    private func moveToStep(_ index: Int) {
        if index >= steps.count {
            phase = .finished
            Haptics.success()
            return
        }
        stepIndex = max(0, index)
        phase = .hold
        remaining = steps[stepIndex].holdSeconds
    }

    private func skipStep() {
        if let step = currentStep {
            skippedItemIndices.insert(step.itemIndex)
        }
        Haptics.light()
        moveToStep(stepIndex + 1)
    }

    private func previousStep() {
        Haptics.light()
        moveToStep(stepIndex - 1)
    }

    private func finishEarly() {
        phase = .finished
    }

    // MARK: Persistence

    private func saveSession() {
        let session = FlexibilitySession(routine: routine)
        session.date = startedAt
        session.durationSeconds = Date().timeIntervalSince(startedAt)
        session.intensity = intensity
        session.notes = notes
        session.status = .completed
        modelContext.insert(session)

        for (itemIndex, item) in routine.orderedItems.enumerated() {
            let itemSteps = steps.filter { $0.itemIndex == itemIndex }
            let done = itemSteps.filter { completedStepIDs.contains($0.id) }.count
            let completed = FlexibilityCompletedItem(
                sortIndex: itemIndex,
                name: item.displayName,
                setsPlanned: itemSteps.count,
                holdSeconds: item.holdSeconds
            )
            completed.setsCompleted = done
            completed.wasSkipped = done == 0 && skippedItemIndices.contains(itemIndex)
            completed.session = session
            modelContext.insert(completed)
        }
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
