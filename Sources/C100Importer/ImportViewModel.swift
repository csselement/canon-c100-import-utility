import AVFoundation
import AppKit
import C100ImportCore
import Foundation
import SwiftUI

enum ImportStatusKind {
    case normal
    case success
}

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var destinationURL: URL?
    @Published var clips: [C100Clip] = []
    @Published var plans: [ImportPlan] = []
    @Published var selectedClipIDs: Set<C100Clip.ID> = []
    @Published var isImporting = false
    @Published var isEjecting = false
    @Published var progressText = "Ready"
    @Published var statusKind: ImportStatusKind = .normal
    @Published var errorMessage: String?
    @Published var importResults: [ImportResult] = []

    private let scanner = C100CardScanner()
    private var mountObserver: NSObjectProtocol?

    var selectedClip: C100Clip? {
        clips.first { selectedClipIDs.contains($0.id) } ?? clips.first
    }

    var canImport: Bool {
        !plans.isEmpty && destinationURL != nil && !isImporting
    }

    var canEjectSource: Bool {
        sourceURL != nil && !isImporting && !isEjecting
    }

    var importButtonTitle: String {
        let count = selectedClipIDs.isEmpty ? clips.count : selectedClipIDs.count
        return count == 1 ? "Import 1 Clip" : "Import \(count) Clips"
    }

    init() {
        installVolumeMountObserver()
        let canonVolume = URL(fileURLWithPath: "/Volumes/CANON", isDirectory: true)
        if FileManager.default.fileExists(atPath: canonVolume.path) {
            sourceURL = canonVolume
            scanSource()
        }
    }

    deinit {
        if let mountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(mountObserver)
        }
    }

    func chooseSource() {
        guard let url = chooseDirectory(title: "Choose Canon C100 SD Card") else {
            return
        }
        sourceURL = url
        scanSource()
    }

    func chooseDestination() {
        guard let url = chooseDirectory(title: "Choose Download Folder") else {
            return
        }
        destinationURL = url
        rebuildPlans()
    }

    func scanSource() {
        guard let sourceURL else {
            return
        }

        do {
            clips = try scanner.scan(root: sourceURL)
            selectedClipIDs = clips.first.map { [$0.id] } ?? []
            progressText = "\(clips.count) C100 clips found"
            errorMessage = nil
            rebuildPlans()
        } catch {
            clips = []
            plans = []
            selectedClipIDs = []
            progressText = "No clips found"
            errorMessage = error.localizedDescription
        }
    }

    func importSelectedClips() {
        guard let destinationURL else {
            return
        }

        isImporting = true
        progressText = "Preparing import..."
        statusKind = .normal
        errorMessage = nil
        importResults = []
        let selectedIDs = selectedClipIDs
        let clipsToImport = selectedIDs.isEmpty
            ? clips
            : clips.filter { selectedIDs.contains($0.id) }
        let currentPlans = C100ImportPlanner(destinationRoot: destinationURL).plan(for: clipsToImport)

        Task.detached(priority: .userInitiated) {
            do {
                let importer = C100ImportCore.C100Importer()
                let results = try importer.importClips(using: currentPlans) { index, total, plan in
                    Task { @MainActor in
                        self.progressText = "Importing \(index) of \(total): \(plan.clip.originalName)"
                    }
                }

                await MainActor.run {
                    self.importResults = results
                    self.isImporting = false
                    self.progressText = "Imported and verified \(results.count) clips"
                }
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.progressText = "Import stopped"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func selectPreviousClip() {
        moveSelection(offset: -1)
    }

    func selectNextClip() {
        moveSelection(offset: 1)
    }

    func ejectSourceCard() {
        guard let sourceURL else {
            return
        }

        isEjecting = true
        errorMessage = nil
        progressText = "Ejecting SD card..."
        statusKind = .normal
        clips = []
        plans = []
        selectedClipIDs = []
        importResults = []

        Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
                try await VolumeEjector().eject(volumeURL: sourceURL)
                self.sourceURL = nil
                self.progressText = "SD card ejected"
                self.statusKind = .success
                self.isEjecting = false
            } catch {
                self.progressText = "Eject failed"
                self.statusKind = .normal
                self.errorMessage = error.localizedDescription
                self.isEjecting = false
            }
        }
    }

    private func rebuildPlans() {
        guard let destinationURL else {
            plans = []
            return
        }
        plans = C100ImportPlanner(destinationRoot: destinationURL).plan(for: clips)
    }

    private func chooseDirectory(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func moveSelection(offset: Int) {
        guard !clips.isEmpty else {
            return
        }

        let currentIndex = selectedClip
            .flatMap { selectedClip in clips.firstIndex(where: { $0.id == selectedClip.id }) }
        let fallbackIndex = offset > 0 ? -1 : clips.count
        let nextIndex = min(max((currentIndex ?? fallbackIndex) + offset, 0), clips.count - 1)
        selectedClipIDs = [clips[nextIndex].id]
    }

    private func installVolumeMountObserver() {
        mountObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else {
                return
            }

            Task { @MainActor in
                self.autoDetectMountedCard(at: url)
            }
        }
    }

    private func autoDetectMountedCard(at url: URL) {
        guard !isImporting, !isEjecting else {
            return
        }

        do {
            let detectedClips = try scanner.scan(root: url)
            guard !detectedClips.isEmpty else {
                return
            }

            sourceURL = url
            clips = detectedClips
            selectedClipIDs = detectedClips.first.map { [$0.id] } ?? []
            errorMessage = nil
            progressText = "Detected \(detectedClips.count) C100 clips on \(url.lastPathComponent)"
            statusKind = .normal
            rebuildPlans()
        } catch {
            return
        }
    }
}
