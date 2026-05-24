import XCTest
@testable import C100ImportCore

final class C100ImportCoreTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryDirectories {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryDirectories.removeAll()
    }

    func testScannerFindsC100AVCHDClipsAndSidecars() throws {
        let root = try makeTemporaryDirectory()
        let stream = root.appendingPathComponent("PRIVATE/AVCHD/BDMV/STREAM", isDirectory: true)
        let clipInfo = root.appendingPathComponent("PRIVATE/AVCHD/BDMV/CLIPINF", isDirectory: true)
        try FileManager.default.createDirectory(at: stream, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: clipInfo, withIntermediateDirectories: true)

        let clipURL = stream.appendingPathComponent("00001.MTS")
        let sidecarURL = clipInfo.appendingPathComponent("00001.CPI")
        try Data("mts-data".utf8).write(to: clipURL)
        try Data("cpi-data".utf8).write(to: sidecarURL)

        let clips = try C100CardScanner().scan(root: root)

        XCTAssertEqual(clips.count, 1)
        XCTAssertEqual(clips[0].sourceURL.standardizedFileURL, clipURL.standardizedFileURL)
        XCTAssertEqual(clips[0].sidecarURL?.standardizedFileURL, sidecarURL.standardizedFileURL)
        XCTAssertEqual(clips[0].byteCount, 8)
    }

    func testPlannerUsesDayFoldersAndTimestampNames() throws {
        let root = try makeTemporaryDirectory()
        let source = root.appendingPathComponent("00001.MTS")
        let destination = root.appendingPathComponent("Imports", isDirectory: true)
        let date = Date(timeIntervalSince1970: 1_716_222_784)
        let clip = C100Clip(sourceURL: source, sidecarURL: nil, byteCount: 12, recordingDate: date)
        let planner = C100ImportPlanner(destinationRoot: destination, timeZone: TimeZone(secondsFromGMT: 0)!)

        let plan = try XCTUnwrap(planner.plan(for: [clip]).first)

        XCTAssertEqual(plan.dayFolderURL.lastPathComponent, "20240520")
        XCTAssertEqual(plan.videoDestinationURL.lastPathComponent, "20240520163304.mts")
    }

    func testImporterCopiesVideoAndSidecarThenVerifiesHashes() throws {
        let root = try makeTemporaryDirectory()
        let sourceFolder = root.appendingPathComponent("Source", isDirectory: true)
        let destination = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)

        let source = sourceFolder.appendingPathComponent("00001.MTS")
        let sidecar = sourceFolder.appendingPathComponent("00001.CPI")
        try Data((0..<4096).map { UInt8($0 % 255) }).write(to: source)
        try Data("sidecar".utf8).write(to: sidecar)

        let clip = C100Clip(sourceURL: source, sidecarURL: sidecar, byteCount: 4096, recordingDate: Date(timeIntervalSince1970: 1_716_222_784))
        let plan = try XCTUnwrap(C100ImportPlanner(destinationRoot: destination, timeZone: TimeZone(secondsFromGMT: 0)!).plan(for: [clip]).first)

        let result = try C100Importer().importClip(using: plan)

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.plan.videoDestinationURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.plan.sidecarDestinationURL!.path))
        XCTAssertTrue(result.videoVerification.matchesSource)
        XCTAssertTrue(result.sidecarVerification?.matchesSource == true)
        XCTAssertEqual(result.videoVerification.sha256, try FileHash().sha256(for: source))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("C100ImportCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryDirectories.append(url)
        return url
    }
}
