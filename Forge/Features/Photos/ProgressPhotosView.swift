import SwiftUI
import SwiftData
import PhotosUI

/// Private progress-photo gallery with import, tagging and side-by-side compare.
struct ProgressPhotosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]

    @State private var angleFilter: PhotoAngle?
    @State private var compareMode = false
    @State private var compareSelection: [ProgressPhoto] = []
    @State private var showImport = false
    @State private var showCompare = false

    private var filtered: [ProgressPhoto] {
        guard let angleFilter else { return photos }
        return photos.filter { $0.angle == angleFilter }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                privacyNote
                filterBar
                if filtered.isEmpty {
                    EmptyStateView(
                        systemImage: "photo.on.rectangle.angled",
                        title: "No photos yet",
                        message: "Progress photos are stored privately inside Forge — never analyzed, never uploaded.",
                        actionTitle: "Add Photo"
                    ) { showImport = true }
                } else {
                    grid
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
        .navigationTitle("Progress Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImport = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(compareMode ? "Cancel" : "Compare") {
                    compareMode.toggle()
                    compareSelection = []
                }
                .font(.forgeCaption)
            }
        }
        .sheet(isPresented: $showImport) {
            PhotoImportView()
        }
        .sheet(isPresented: $showCompare, onDismiss: {
            compareMode = false
            compareSelection = []
        }) {
            if compareSelection.count == 2 {
                PhotoCompareView(left: compareSelection[0], right: compareSelection[1])
            }
        }
    }

    private var privacyNote: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Theme.accent)
            Text("Stored only on this device (and your private iCloud if enabled). Forge never analyzes or shares your photos.")
                .font(.forgeCaption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(Theme.surface))
    }

    private var filterBar: some View {
        HStack(spacing: Spacing.s) {
            Button {
                angleFilter = nil
            } label: {
                TagChip(text: "All", tint: Theme.body, isSelected: angleFilter == nil)
            }
            .buttonStyle(.plain)
            ForEach(PhotoAngle.allCases) { angle in
                Button {
                    angleFilter = angleFilter == angle ? nil : angle
                } label: {
                    TagChip(text: angle.displayName, tint: Theme.body, isSelected: angleFilter == angle)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: Spacing.s)], spacing: Spacing.s) {
            ForEach(filtered, id: \.id) { photo in
                photoCell(photo)
            }
        }
    }

    @ViewBuilder
    private func photoCell(_ photo: ProgressPhoto) -> some View {
        let isSelected = compareSelection.contains { $0.id == photo.id }
        Group {
            if compareMode {
                Button {
                    toggleCompare(photo)
                } label: {
                    thumbnail(photo)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? Theme.accent : .white.opacity(0.8))
                                .padding(6)
                        }
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    PhotoDetailView(photo: photo)
                } label: {
                    thumbnail(photo)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func thumbnail(_ photo: ProgressPhoto) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let data = photo.thumbnailData ?? Optional(photo.imageData),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            }
            Text(photo.angleDisplayName)
                .font(.forgeOverline)
                .foregroundStyle(Theme.textTertiary)
            Text(Formatting.shortDate(photo.date))
                .font(.forgeCaption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func toggleCompare(_ photo: ProgressPhoto) {
        if let index = compareSelection.firstIndex(where: { $0.id == photo.id }) {
            compareSelection.remove(at: index)
        } else {
            compareSelection.append(photo)
            if compareSelection.count == 2 {
                showCompare = true
            }
        }
        Haptics.light()
    }
}

/// Import a photo from the library with angle, date, weight, tags and notes.
struct PhotoImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var angle: PhotoAngle = .front
    @State private var customAngleLabel = ""
    @State private var date = Date()
    @State private var bodyWeightDisplay: Double?
    @State private var notes = ""
    @State private var tagsText = ""

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(imageData == nil ? "Choose Photo" : "Replace Photo", systemImage: "photo.badge.plus")
                    }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.m))
                    }
                }
                Section("Details") {
                    Picker("Angle", selection: $angle) {
                        ForEach(PhotoAngle.allCases) { Text($0.displayName).tag($0) }
                    }
                    if angle == .custom {
                        TextField("Angle label", text: $customAngleLabel)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Body weight")
                        Spacer()
                        TextField("Optional", value: $bodyWeightDisplay, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text((settings?.weightUnit ?? .kilograms).suffix)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    TextField("Tags (comma separated)", text: $tagsText)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Text("The photo is copied into Forge's private storage at reduced size. The original in your library is untouched.")
                        .font(.forgeCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(imageData == nil)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let raw = try? await newItem.loadTransferable(type: Data.self) {
                        imageData = ImageProcessor.compressedImageData(from: raw, maxDimension: 1600)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let imageData else { return }
        let photo = ProgressPhoto(
            date: date,
            angle: angle,
            imageData: imageData,
            thumbnailData: ImageProcessor.thumbnailData(from: imageData)
        )
        photo.customAngleLabel = customAngleLabel
        photo.notes = notes
        photo.tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let bodyWeightDisplay {
            photo.bodyWeightKg = UnitsConverter.weightKg(fromDisplay: bodyWeightDisplay, unit: settings?.weightUnit ?? .kilograms)
        }
        modelContext.insert(photo)
        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}

/// Full-size photo with metadata and delete.
struct PhotoDetailView: View {
    @Bindable var photo: ProgressPhoto

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    @State private var showDeleteConfirm = false

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if let image = UIImage(data: photo.imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                }
                Card {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        HStack(spacing: Spacing.l) {
                            StatTile(label: "Angle", value: photo.angleDisplayName)
                            StatTile(label: "Date", value: Formatting.mediumDate(photo.date))
                            if let weight = photo.bodyWeightKg {
                                StatTile(label: "Weight", value: Formatting.weight(weight, unit: settings?.weightUnit ?? .kilograms))
                            }
                        }
                        if !photo.tags.isEmpty {
                            HStack(spacing: Spacing.xs) {
                                ForEach(photo.tags, id: \.self) { tag in
                                    TagChip(text: tag, tint: Theme.body)
                                }
                            }
                        }
                        if !photo.notes.isEmpty {
                            Text(photo.notes)
                                .font(.forgeBody)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                Button {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Photo", systemImage: "trash")
                }
                .buttonStyle(DangerButtonStyle())
            }
            .padding(Spacing.l)
        }
        .background(Theme.background)
        .navigationTitle(Formatting.shortDate(photo.date))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this photo?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Photo", role: .destructive) {
                modelContext.delete(photo)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("The copy stored in Forge is removed permanently.")
        }
    }
}

/// Side-by-side comparison preserving each photo's aspect ratio.
struct PhotoCompareView: View {
    let left: ProgressPhoto
    let right: ProgressPhoto

    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    HStack(alignment: .top, spacing: Spacing.s) {
                        comparePane(left)
                        comparePane(right)
                    }
                    deltaCard
                }
                .padding(Spacing.l)
            }
            .background(Theme.background)
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func comparePane(_ photo: ProgressPhoto) -> some View {
        VStack(spacing: Spacing.xs) {
            if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            }
            Text(Formatting.mediumDate(photo.date))
                .font(.forgeCaption)
                .foregroundStyle(Theme.textPrimary)
            if let weight = photo.bodyWeightKg {
                Text(Formatting.weight(weight, unit: settings?.weightUnit ?? .kilograms))
                    .font(.forgeOverline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var deltaCard: some View {
        let days = abs(Calendar.current.dateComponents([.day], from: left.date, to: right.date).day ?? 0)
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Between Photos")
                HStack(spacing: Spacing.l) {
                    StatTile(label: "Time apart", value: "\(days) days")
                    if let leftWeight = left.bodyWeightKg, let rightWeight = right.bodyWeightKg {
                        let deltaKg = rightWeight - leftWeight
                        let unit = settings?.weightUnit ?? .kilograms
                        let display = UnitsConverter.displayWeight(kg: deltaKg, unit: unit)
                        StatTile(label: "Weight Δ",
                                 value: "\(display >= 0 ? "+" : "")\(Formatting.trimmed(display, maxDecimals: 1)) \(unit.suffix)",
                                 tint: Theme.body)
                    }
                }
            }
        }
    }
}
