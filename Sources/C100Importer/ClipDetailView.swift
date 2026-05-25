import AVKit
import C100ImportCore
import SwiftUI

struct ClipDetailView: View {
    let clip: C100Clip
    let plan: ImportPlan?
    @State private var player: AVPlayer?
    @State private var playbackKeyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VideoPlayer(player: player)
                .frame(minHeight: 360)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onAppear {
                    player = AVPlayer(url: clip.sourceURL)
                }
                .onChange(of: clip.id) {
                    releasePlayer()
                    player = AVPlayer(url: clip.sourceURL)
                }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow {
                    Text("Source")
                        .foregroundStyle(.secondary)
                    Text(clip.sourceURL.path)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Recording")
                        .foregroundStyle(.secondary)
                    Text(clip.recordingDate.formatted(date: .complete, time: .standard))
                }
                GridRow {
                    Text("Destination")
                        .foregroundStyle(.secondary)
                    Text(plan?.videoDestinationURL.path ?? "Choose a download folder")
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Sidecar")
                        .foregroundStyle(.secondary)
                    Text(clip.sidecarURL?.lastPathComponent ?? "Missing")
                }
            }
            .font(.callout)

            Spacer(minLength: 0)
        }
        .padding(18)
        .navigationTitle(clip.originalName)
        .onAppear {
            installPlaybackKeyMonitor()
        }
        .onDisappear {
            removePlaybackKeyMonitor()
            releasePlayer()
        }
    }

    private func installPlaybackKeyMonitor() {
        guard playbackKeyMonitor == nil else {
            return
        }

        playbackKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isDedicatedPlaybackEvent(event) else {
                return event
            }

            switch event.keyCode {
            case KeyCode.leftArrow:
                if !event.isARepeat {
                    seek(by: -5)
                }
                return nil
            case KeyCode.rightArrow:
                if !event.isARepeat {
                    seek(by: 5)
                }
                return nil
            default:
                break
            }

            guard event.charactersIgnoringModifiers == " " else {
                return event
            }

            if !event.isARepeat {
                togglePlayback()
            }
            return nil
        }
    }

    private func removePlaybackKeyMonitor() {
        if let playbackKeyMonitor {
            NSEvent.removeMonitor(playbackKeyMonitor)
            self.playbackKeyMonitor = nil
        }
    }

    private func togglePlayback() {
        guard let player else {
            return
        }

        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    private func seek(by seconds: Double) {
        guard let player else {
            return
        }

        let currentSeconds = player.currentTime().seconds
        guard currentSeconds.isFinite else {
            return
        }

        let targetSeconds = max(currentSeconds + seconds, 0)
        player.seek(to: CMTime(seconds: targetSeconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func releasePlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func isDedicatedPlaybackEvent(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty
    }
}

private enum KeyCode {
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
}
