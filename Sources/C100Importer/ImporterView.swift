import AVKit
import C100ImportCore
import SwiftUI

struct ImporterView: View {
    @StateObject private var viewModel = ImportViewModel()
    @State private var arrowKeyMonitor: Any?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .onAppear {
            installArrowKeyMonitor()
        }
        .onDisappear {
            removeArrowKeyMonitor()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sourceControls
            Divider()
            clipList
            Divider()
            importControls
        }
        .frame(minWidth: 360)
    }

    private var sourceControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            ImporterHeader()

            VStack(spacing: 10) {
                SourcePickerRow(
                    title: "Card",
                    icon: "sdcard",
                    url: viewModel.sourceURL,
                    placeholder: "Choose SD card",
                    primaryActionTitle: "Choose",
                    primaryAction: viewModel.chooseSource,
                    secondaryAction: viewModel.scanSource,
                    ejectAction: viewModel.ejectSourceCard,
                    isEjectEnabled: viewModel.canEjectSource
                )

                SourcePickerRow(
                    title: "Download",
                    icon: "folder",
                    url: viewModel.destinationURL,
                    placeholder: "Choose download folder",
                    primaryActionTitle: "Choose",
                    primaryAction: viewModel.chooseDestination
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private var clipList: some View {
        List(selection: $viewModel.selectedClipIDs) {
            ForEach(viewModel.clips) { clip in
                ClipRow(clip: clip)
                    .tag(clip.id)
            }
        }
        .overlay {
            if viewModel.clips.isEmpty {
                ContentUnavailableView("No C100 Clips", systemImage: "video.slash", description: Text("Choose a card with PRIVATE/AVCHD/BDMV/STREAM."))
            }
        }
    }

    private var importControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.progressText)
                    .lineLimit(2)
                Spacer()
                Button {
                    viewModel.importSelectedClips()
                } label: {
                    Label(viewModel.importButtonTitle, systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canImport)
            }

            if viewModel.isImporting {
                ProgressView()
                    .progressViewStyle(.linear)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            if !viewModel.importResults.isEmpty {
                Label("\(viewModel.importResults.count) clips verified by SHA-256", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var detail: some View {
        if let clip = viewModel.selectedClip {
            ClipDetailView(clip: clip, plan: viewModel.plans.first { $0.clip.id == clip.id })
        } else {
            ContentUnavailableView("Select a Clip", systemImage: "video")
        }
    }

    private func installArrowKeyMonitor() {
        guard arrowKeyMonitor == nil else {
            return
        }

        arrowKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isDedicatedArrowEvent(event) else {
                return event
            }

            switch event.keyCode {
            case KeyCode.upArrow:
                if !event.isARepeat {
                    viewModel.selectPreviousClip()
                }
                return nil
            case KeyCode.downArrow:
                if !event.isARepeat {
                    viewModel.selectNextClip()
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeArrowKeyMonitor() {
        if let arrowKeyMonitor {
            NSEvent.removeMonitor(arrowKeyMonitor)
            self.arrowKeyMonitor = nil
        }
    }

    private func isDedicatedArrowEvent(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty
    }
}

private enum KeyCode {
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}

private struct ImporterHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "video.badge.checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .background(.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text("Canon C100 Importer")
                    .font(.headline)
                Text("AVCHD card ingest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SourcePickerRow: View {
    let title: String
    let icon: String
    let url: URL?
    let placeholder: String
    let primaryActionTitle: String
    let primaryAction: () -> Void
    var secondaryAction: (() -> Void)?
    var ejectAction: (() -> Void)?
    var isEjectEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Button {
                    primaryAction()
                } label: {
                    Text(primaryActionTitle)
                        .frame(minWidth: 56)
                }
                .controlSize(.small)

                if let secondaryAction {
                    Button {
                        secondaryAction()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .help("Rescan source")
                }

                if let ejectAction {
                    Button {
                        ejectAction()
                    } label: {
                        Image(systemName: "eject")
                    }
                    .controlSize(.small)
                    .disabled(!isEjectEnabled)
                    .help("Eject SD card")
                }
            }

            Text(url?.path ?? placeholder)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(url == nil ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(12)
        .background(.background.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
        }
    }
}

private struct ClipRow: View {
    let clip: C100Clip

    var body: some View {
        HStack(spacing: 10) {
            PosterFrameView(url: clip.sourceURL)
                .frame(width: 88, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(clip.originalName)
                    .font(.headline)
                Text(clip.recordingDate.formatted(date: .numeric, time: .standard))
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: Int64(clip.byteCount), countStyle: .file))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
