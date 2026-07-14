import SwiftUI
import SwiftData
import PhotosUI

/// Create or edit an exercise. Pass nil to create.
struct ExerciseEditorView: View {
    var exercise: Exercise?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var name = ""
    @State private var primaryMuscle = MuscleGroup.chest.rawValue
    @State private var secondaryMuscles: Set<String> = []
    @State private var category: ExerciseCategory = .strength
    @State private var equipment = EquipmentType.barbell.rawValue
    @State private var movementPattern: MovementPattern = .other
    @State private var instructions = ""
    @State private var personalNotes = ""
    @State private var isUnilateral = false
    @State private var usesWeight = true
    @State private var usesReps = true
    @State private var usesDuration = false
    @State private var usesDistance = false
    @State private var tracksRPE = true
    @State private var incrementKg = 2.5
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var loaded = false

    private var settings: AppSettings? { settingsList.first }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("exercise.name")
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Primary Muscle", selection: $primaryMuscle) {
                        ForEach(settings?.allMuscleGroupOptions ?? MuscleGroup.allCases.map(\.rawValue), id: \.self) {
                            Text(MuscleGroup.displayName(for: $0)).tag($0)
                        }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(settings?.allEquipmentOptions ?? EquipmentType.allCases.map(\.rawValue), id: \.self) {
                            Text(EquipmentType.displayName(for: $0)).tag($0)
                        }
                    }
                    Picker("Movement Pattern", selection: $movementPattern) {
                        ForEach(MovementPattern.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section("Secondary Muscles") {
                    ForEach(settings?.allMuscleGroupOptions ?? MuscleGroup.allCases.map(\.rawValue), id: \.self) { raw in
                        if raw != primaryMuscle {
                            Button {
                                if secondaryMuscles.contains(raw) {
                                    secondaryMuscles.remove(raw)
                                } else {
                                    secondaryMuscles.insert(raw)
                                }
                            } label: {
                                HStack {
                                    Text(MuscleGroup.displayName(for: raw))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    if secondaryMuscles.contains(raw) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Tracking") {
                    Toggle("Uses Weight", isOn: $usesWeight)
                    Toggle("Uses Repetitions", isOn: $usesReps)
                    Toggle("Uses Duration", isOn: $usesDuration)
                    Toggle("Uses Distance", isOn: $usesDistance)
                    Toggle("Track RPE", isOn: $tracksRPE)
                    Toggle("Unilateral (per side)", isOn: $isUnilateral)
                    if usesWeight {
                        HStack {
                            Text("Weight Increment")
                            Spacer()
                            TextField("2.5", value: $incrementKg, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text("kg").foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                Section("Details") {
                    TextField("Instructions", text: $instructions, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("Personal notes", text: $personalNotes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Image") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(imageData == nil ? "Add Image" : "Replace Image", systemImage: "photo")
                    }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                        Button("Remove Image", role: .destructive) { self.imageData = nil }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("exercise.save")
                }
            }
            .onAppear { loadIfNeeded() }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        imageData = ImageProcessor.compressedImageData(from: data, maxDimension: 1200)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadIfNeeded() {
        guard !loaded, let exercise else { loaded = true; return }
        loaded = true
        name = exercise.name
        primaryMuscle = exercise.primaryMuscleRaw
        secondaryMuscles = Set(exercise.secondaryMusclesRaw)
        category = exercise.category
        equipment = exercise.equipmentRaw
        movementPattern = MovementPattern(rawValue: exercise.movementPatternRaw) ?? .other
        instructions = exercise.instructions
        personalNotes = exercise.personalNotes
        isUnilateral = exercise.isUnilateral
        usesWeight = exercise.usesWeight
        usesReps = exercise.usesReps
        usesDuration = exercise.usesDuration
        usesDistance = exercise.usesDistance
        tracksRPE = exercise.tracksRPE
        incrementKg = exercise.defaultIncrementKg
        imageData = exercise.imageData
    }

    private func save() {
        let target: Exercise
        if let exercise {
            target = exercise
        } else {
            target = Exercise(name: name)
            modelContext.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.primaryMuscleRaw = primaryMuscle
        target.secondaryMusclesRaw = Array(secondaryMuscles.subtracting([primaryMuscle]))
        target.categoryRaw = category.rawValue
        target.equipmentRaw = equipment
        target.movementPatternRaw = movementPattern.rawValue
        target.instructions = instructions
        target.personalNotes = personalNotes
        target.isUnilateral = isUnilateral
        target.usesWeight = usesWeight
        target.usesReps = usesReps
        target.usesDuration = usesDuration
        target.usesDistance = usesDistance
        target.tracksRPE = tracksRPE
        target.defaultIncrementKg = max(0, incrementKg)
        target.imageData = imageData
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
