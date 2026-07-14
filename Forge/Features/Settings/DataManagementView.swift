import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Backup, export, restore and full deletion — with explicit confirmations
/// and validation so data is never silently lost.
struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var backupURL: URL?
    @State private var csvURLs: [URL] = []
    @State private var includePhotos = false
    @State private var isWorking = false
    @State private var showImporter = false
    @State private var pendingRestore: BackupDocument?
    @State private var restoreSummary: BackupValidationSummary?
    @State private var resultMessage: String?
    @State private var errorMessage: String?
    @State private var deleteConfirmationText = ""
    @State private var showDeleteSheet = false

    var body: some View {
        Form {
            Section {
                Toggle("Include photos in backup", isOn: $includePhotos)
                    .tint(Theme.accent)
                Button {
                    createBackup()
                } label: {
                    HStack {
                        Label("Create JSON Backup", systemImage: "arrow.down.doc")
                        if isWorking { Spacer(); ProgressView() }
                    }
                }
                .disabled(isWorking)
                if let backupURL {
                    ShareLink(item: backupURL) {
                        Label("Share Backup File", systemImage: "square.and.arrow.up")
                            .foregroundStyle(Theme.accent)
                    }
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("A complete, human-readable JSON snapshot of your data. Including photos makes the file much larger.")
            }

            Section {
                Button {
                    exportCSV()
                } label: {
                    Label("Generate CSV Files", systemImage: "tablecells")
                }
                ForEach(csvURLs, id: \.self) { url in
                    ShareLink(item: url) {
                        Label(url.lastPathComponent, systemImage: "square.and.arrow.up")
                            .foregroundStyle(Theme.accent)
                    }
                }
            } header: {
                Text("CSV Export")
            } footer: {
                Text("Workouts (one row per set), runs, and body measurements — for spreadsheets or other tools.")
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Restore from Backup…", systemImage: "arrow.up.doc")
                }
            } header: {
                Text("Restore")
            } footer: {
                Text("Restoring merges the backup into your current data. Records that already exist (same ID) are skipped — nothing is overwritten or deleted.")
            }

            if let resultMessage {
                Section {
                    Label(resultMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(Theme.accent)
                }
            }

            Section {
                Button(role: .destructive) {
                    deleteConfirmationText = ""
                    showDeleteSheet = true
                } label: {
                    Label("Delete All Data…", systemImage: "trash")
                }
            } footer: {
                Text("Removes every workout, run, measurement, photo and setting from this device. Create a backup first.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Backup & Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert("Restore Backup?", isPresented: Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil; restoreSummary = nil } }
        )) {
            Button("Merge into My Data") { performRestore() }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            if let summary = restoreSummary {
                Text(restoreDescription(summary))
            }
        }
        .alert("Problem", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showDeleteSheet) { deleteSheet }
    }

    // MARK: Backup / export

    private func createBackup() {
        isWorking = true
        // Building a large backup synchronously is fine for personal data sizes;
        // done on the next runloop so the spinner appears.
        DispatchQueue.main.async {
            do {
                backupURL = try ExportImportService.exportBackupFile(in: modelContext, includePhotos: includePhotos)
                resultMessage = "Backup ready — share it to save it somewhere safe."
                Haptics.success()
            } catch {
                errorMessage = "Backup failed: \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    private func exportCSV() {
        do {
            csvURLs = try ExportImportService.exportCSVFiles(in: modelContext)
            Haptics.success()
        } catch {
            errorMessage = "CSV export failed: \(error.localizedDescription)"
        }
    }

    // MARK: Restore

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = "Could not open file: \(error.localizedDescription)"
        case .success(let url):
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = BackupValidationError.unreadableFile.description
                return
            }
            switch BackupValidator.decode(data) {
            case .failure(let error):
                errorMessage = error.description
            case .success(let document):
                switch BackupValidator.validate(document) {
                case .failure(let error):
                    errorMessage = error.description
                case .success(let summary):
                    pendingRestore = document
                    restoreSummary = summary
                }
            }
        }
    }

    private func restoreDescription(_ summary: BackupValidationSummary) -> String {
        var lines = [
            "This backup contains \(summary.exerciseCount) exercises, \(summary.sessionCount) workouts, \(summary.runCount) runs, \(summary.flexSessionCount) flexibility sessions, \(summary.bodyEntryCount) measurements and \(summary.photoCount) photos.",
            "It will be merged into your existing data — duplicates are skipped, nothing is deleted.",
        ]
        lines.append(contentsOf: summary.warnings)
        return lines.joined(separator: "\n")
    }

    private func performRestore() {
        guard let pendingRestore else { return }
        let result = ExportImportService.restore(pendingRestore, into: modelContext)
        resultMessage = "Restored \(result.imported) records (\(result.skippedDuplicates) duplicates skipped)."
        self.pendingRestore = nil
        restoreSummary = nil
        Haptics.success()
    }

    // MARK: Delete all

    private var deleteSheet: some View {
        NavigationStack {
            VStack(spacing: Spacing.l) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.danger)
                    .padding(.top, Spacing.xxl)
                Text("Delete everything?")
                    .font(.forgeTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("Every workout, run, flexibility session, measurement, photo and record will be permanently deleted from this device. This cannot be undone.\n\nType DELETE to confirm.")
                    .font(.forgeSubheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                TextField("Type DELETE", text: $deleteConfirmationText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.forgeHeadline)
                    .padding(Spacing.m)
                    .background(RoundedRectangle(cornerRadius: Radius.m).fill(Theme.surfaceElevated))
                Button {
                    ExportImportService.deleteAllData(in: modelContext)
                    SeedData.seedIfNeeded(context: modelContext)
                    showDeleteSheet = false
                    resultMessage = "All data deleted. Starter content was re-created."
                    Haptics.warning()
                } label: {
                    Text("Permanently Delete All Data")
                }
                .buttonStyle(DangerButtonStyle())
                .disabled(deleteConfirmationText != "DELETE")
                Spacer()
            }
            .padding(Spacing.xl)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDeleteSheet = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
