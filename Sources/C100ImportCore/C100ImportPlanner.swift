import Foundation

public struct C100ImportPlanner: Sendable {
    public let destinationRoot: URL
    public let calendar: Calendar
    public let timeZone: TimeZone

    public init(destinationRoot: URL, calendar: Calendar = .current, timeZone: TimeZone = .current) {
        self.destinationRoot = destinationRoot
        var configuredCalendar = calendar
        configuredCalendar.timeZone = timeZone
        self.calendar = configuredCalendar
        self.timeZone = timeZone
    }

    public func plan(for clips: [C100Clip]) -> [ImportPlan] {
        var usedNamesByFolder: [URL: Set<String>] = [:]

        return clips
            .sorted { $0.recordingDate < $1.recordingDate }
            .map { clip in
                let folderName = Self.dayFormatter(timeZone: timeZone).string(from: clip.recordingDate)
                let baseName = Self.timestampFormatter(timeZone: timeZone).string(from: clip.recordingDate)
                let dayFolder = destinationRoot.appendingPathComponent(folderName, isDirectory: true)
                let videoName = uniqueName(baseName: baseName, extension: "mts", folder: dayFolder, usedNamesByFolder: &usedNamesByFolder)
                let videoDestination = dayFolder.appendingPathComponent(videoName)
                let sidecarDestination = clip.sidecarURL == nil
                    ? nil
                    : dayFolder.appendingPathComponent(videoDestination.deletingPathExtension().lastPathComponent).appendingPathExtension("CPI")

                return ImportPlan(
                    clip: clip,
                    dayFolderURL: dayFolder,
                    videoDestinationURL: videoDestination,
                    sidecarDestinationURL: sidecarDestination
                )
            }
    }

    public static func dayFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }

    public static func timestampFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter
    }

    private func uniqueName(
        baseName: String,
        extension pathExtension: String,
        folder: URL,
        usedNamesByFolder: inout [URL: Set<String>]
    ) -> String {
        let normalizedExtension = pathExtension.lowercased()
        var names = usedNamesByFolder[folder, default: []]
        var candidate = "\(baseName).\(normalizedExtension)"
        var index = 2

        while names.contains(candidate) || FileManager.default.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = "\(baseName)-\(String(format: "%02d", index)).\(normalizedExtension)"
            index += 1
        }

        names.insert(candidate)
        usedNamesByFolder[folder] = names
        return candidate
    }
}

