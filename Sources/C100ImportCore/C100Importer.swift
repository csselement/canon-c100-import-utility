import Foundation

public enum C100ImporterError: LocalizedError, Equatable {
    case destinationExists(URL)
    case missingSidecar(URL)
    case verificationFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .destinationExists(let url):
            return "Destination already exists: \(url.path)"
        case .missingSidecar(let url):
            return "The expected sidecar does not exist: \(url.path)"
        case .verificationFailed(let url):
            return "Verification failed for \(url.path)"
        }
    }
}

public final class C100Importer {
    private let fileManager: FileManager
    private let hasher: FileHash

    public init(fileManager: FileManager = .default, hasher: FileHash = FileHash()) {
        self.fileManager = fileManager
        self.hasher = hasher
    }

    public func importClips(
        using plans: [ImportPlan],
        progress: (@Sendable (Int, Int, ImportPlan) -> Void)? = nil
    ) throws -> [ImportResult] {
        var results: [ImportResult] = []
        for (index, plan) in plans.enumerated() {
            progress?(index + 1, plans.count, plan)
            results.append(try importClip(using: plan))
        }
        return results
    }

    public func importClip(using plan: ImportPlan) throws -> ImportResult {
        try fileManager.createDirectory(at: plan.dayFolderURL, withIntermediateDirectories: true)
        let videoVerification = try copyAndVerify(source: plan.clip.sourceURL, destination: plan.videoDestinationURL)

        let sidecarVerification: FileVerification?
        if let sourceSidecar = plan.clip.sidecarURL, let sidecarDestination = plan.sidecarDestinationURL {
            guard fileManager.fileExists(atPath: sourceSidecar.path) else {
                throw C100ImporterError.missingSidecar(sourceSidecar)
            }
            sidecarVerification = try copyAndVerify(source: sourceSidecar, destination: sidecarDestination)
        } else {
            sidecarVerification = nil
        }

        return ImportResult(plan: plan, videoVerification: videoVerification, sidecarVerification: sidecarVerification)
    }

    public func verify(source: URL, destination: URL) throws -> FileVerification {
        let sourceAttributes = try fileManager.attributesOfItem(atPath: source.path)
        let destinationAttributes = try fileManager.attributesOfItem(atPath: destination.path)
        let sourceSize = (sourceAttributes[.size] as? NSNumber)?.uint64Value ?? 0
        let destinationSize = (destinationAttributes[.size] as? NSNumber)?.uint64Value ?? 0
        let sourceHash = try hasher.sha256(for: source)
        let destinationHash = try hasher.sha256(for: destination)
        let matches = sourceSize == destinationSize && sourceHash == destinationHash

        return FileVerification(
            sourceURL: source,
            destinationURL: destination,
            byteCount: destinationSize,
            sha256: destinationHash,
            matchesSource: matches
        )
    }

    private func copyAndVerify(source: URL, destination: URL) throws -> FileVerification {
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw C100ImporterError.destinationExists(destination)
        }

        try fileManager.copyItem(at: source, to: destination)
        let verification = try verify(source: source, destination: destination)
        guard verification.matchesSource else {
            try? fileManager.removeItem(at: destination)
            throw C100ImporterError.verificationFailed(destination)
        }
        return verification
    }
}
