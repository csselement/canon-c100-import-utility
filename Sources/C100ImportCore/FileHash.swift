import CryptoKit
import Foundation

public enum FileHashError: LocalizedError {
    case unreadable(URL)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            return "Could not read \(url.path) for hashing."
        }
    }
}

public struct FileHash: Sendable {
    public init() {}

    public func sha256(for url: URL) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw FileHashError.unreadable(url)
        }
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1024 * 1024)
            guard !data.isEmpty else {
                return false
            }
            hasher.update(data: data)
            return true
        }) {}

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

