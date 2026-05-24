import Foundation

public enum C100CardScannerError: LocalizedError, Equatable {
    case streamFolderNotFound(URL)

    public var errorDescription: String? {
        switch self {
        case .streamFolderNotFound(let root):
            return "No C100 AVCHD stream folder was found at \(root.path). Expected PRIVATE/AVCHD/BDMV/STREAM."
        }
    }
}

public struct C100CardScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func streamFolder(in root: URL) throws -> URL {
        let candidates = [
            root.appendingPathComponent("PRIVATE/AVCHD/BDMV/STREAM", isDirectory: true),
            root.appendingPathComponent("AVCHD/BDMV/STREAM", isDirectory: true),
            root.appendingPathComponent("BDMV/STREAM", isDirectory: true),
            root
        ]

        for candidate in candidates where isDirectory(candidate) {
            if candidate.lastPathComponent.uppercased() == "STREAM" {
                return candidate
            }
        }

        throw C100CardScannerError.streamFolderNotFound(root)
    }

    public func scan(root: URL) throws -> [C100Clip] {
        let stream = try streamFolder(in: root)
        let clipInfo = stream.deletingLastPathComponent().appendingPathComponent("CLIPINF", isDirectory: true)
        let urls = try fileManager.contentsOfDirectory(
            at: stream,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return try urls
            .filter { $0.pathExtension.caseInsensitiveCompare("mts") == .orderedSame }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let values = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey])
                let sidecar = clipInfo
                    .appendingPathComponent(url.deletingPathExtension().lastPathComponent)
                    .appendingPathExtension("CPI")
                return C100Clip(
                    sourceURL: url,
                    sidecarURL: fileManager.fileExists(atPath: sidecar.path) ? sidecar : nil,
                    byteCount: UInt64(values.fileSize ?? 0),
                    recordingDate: values.creationDate ?? values.contentModificationDate ?? .distantPast
                )
            }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
