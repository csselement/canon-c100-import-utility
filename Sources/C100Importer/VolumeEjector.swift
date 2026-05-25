import DiskArbitration
import Foundation

enum VolumeEjectorError: LocalizedError {
    case sessionUnavailable
    case diskUnavailable(URL)
    case unmountFailed(DADissenter?)
    case ejectFailed(DADissenter?)

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            return "Could not create a disk arbitration session."
        case .diskUnavailable(let url):
            return "Could not find the mounted disk for \(url.path)."
        case .unmountFailed(let dissenter):
            return "Could not unmount the SD card. \(Self.message(from: dissenter))"
        case .ejectFailed(let dissenter):
            return "Could not eject the SD card. \(Self.message(from: dissenter))"
        }
    }

    private static func message(from dissenter: DADissenter?) -> String {
        guard let dissenter else {
            return "No additional error was reported."
        }

        let status = DADissenterGetStatus(dissenter)
        let statusText = DADissenterGetStatusString(dissenter) as String? ?? fallbackMessage(for: status)
        return "\(statusText) (\(status))."
    }

    private static func fallbackMessage(for status: DAReturn) -> String {
        switch status {
        case DAReturn(kDAReturnBusy):
            return "The volume is busy. Another process still has a file open on the SD card."
        case DAReturn(kDAReturnNotPermitted):
            return "The unmount request was not permitted."
        case DAReturn(kDAReturnNotPrivileged):
            return "The unmount request needs additional privileges."
        case DAReturn(kDAReturnUnsupported):
            return "The card was unmounted, but this reader does not support a separate eject operation."
        case 49168:
            return "The volume is busy. A file is still open on the SD card."
        default:
            return "Unknown error"
        }
    }
}

struct VolumeEjector {
    func eject(volumeURL: URL) async throws {
        let volumePath = volumeURL.path
        let fileURL = volumeURL as CFURL
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            throw VolumeEjectorError.sessionUnavailable
        }
        guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, fileURL) else {
            throw VolumeEjectorError.diskUnavailable(volumeURL)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let unmountContext = ContinuationBox(continuation: continuation, session: session, volumePath: volumePath)
            DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            DADiskUnmount(disk, DADiskUnmountOptions(kDADiskUnmountOptionDefault), { disk, dissenter, context in
                let box = Unmanaged<ContinuationBox>
                    .fromOpaque(context!)
                    .takeRetainedValue()

                guard dissenter == nil else {
                    DASessionUnscheduleFromRunLoop(box.session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
                    box.continuation.resume(throwing: VolumeEjectorError.unmountFailed(dissenter))
                    return
                }

                DADiskEject(disk, DADiskEjectOptions(kDADiskEjectOptionDefault), { _, dissenter, context in
                    let box = Unmanaged<ContinuationBox>
                        .fromOpaque(context!)
                        .takeRetainedValue()
                    DASessionUnscheduleFromRunLoop(box.session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

                    if let dissenter {
                        if !Self.isMounted(volumePath: box.volumePath) {
                            box.continuation.resume()
                        } else {
                            box.continuation.resume(throwing: VolumeEjectorError.ejectFailed(dissenter))
                        }
                    } else {
                        box.continuation.resume()
                    }
                }, Unmanaged.passRetained(box).toOpaque())
            }, Unmanaged.passRetained(unmountContext).toOpaque())
        }
    }

    private static func isMounted(volumePath: String) -> Bool {
        let mountedVolumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) ?? []

        return mountedVolumeURLs.contains { $0.path == volumePath }
    }
}

private final class ContinuationBox {
    let continuation: CheckedContinuation<Void, Error>
    let session: DASession
    let volumePath: String

    init(continuation: CheckedContinuation<Void, Error>, session: DASession, volumePath: String) {
        self.continuation = continuation
        self.session = session
        self.volumePath = volumePath
    }
}
