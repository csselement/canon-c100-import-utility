import Foundation

public struct C100Clip: Identifiable, Hashable, Sendable {
    public let id: String
    public let sourceURL: URL
    public let sidecarURL: URL?
    public let originalName: String
    public let byteCount: UInt64
    public let recordingDate: Date

    public init(sourceURL: URL, sidecarURL: URL?, byteCount: UInt64, recordingDate: Date) {
        self.sourceURL = sourceURL
        self.sidecarURL = sidecarURL
        self.originalName = sourceURL.lastPathComponent
        self.byteCount = byteCount
        self.recordingDate = recordingDate
        self.id = sourceURL.path
    }
}

public struct ImportPlan: Hashable, Sendable {
    public let clip: C100Clip
    public let dayFolderURL: URL
    public let videoDestinationURL: URL
    public let sidecarDestinationURL: URL?

    public init(clip: C100Clip, dayFolderURL: URL, videoDestinationURL: URL, sidecarDestinationURL: URL?) {
        self.clip = clip
        self.dayFolderURL = dayFolderURL
        self.videoDestinationURL = videoDestinationURL
        self.sidecarDestinationURL = sidecarDestinationURL
    }
}

public struct FileVerification: Hashable, Sendable {
    public let sourceURL: URL
    public let destinationURL: URL
    public let byteCount: UInt64
    public let sha256: String
    public let matchesSource: Bool

    public init(sourceURL: URL, destinationURL: URL, byteCount: UInt64, sha256: String, matchesSource: Bool) {
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.byteCount = byteCount
        self.sha256 = sha256
        self.matchesSource = matchesSource
    }
}

public struct ImportResult: Hashable, Sendable {
    public let plan: ImportPlan
    public let videoVerification: FileVerification
    public let sidecarVerification: FileVerification?

    public init(plan: ImportPlan, videoVerification: FileVerification, sidecarVerification: FileVerification?) {
        self.plan = plan
        self.videoVerification = videoVerification
        self.sidecarVerification = sidecarVerification
    }
}

