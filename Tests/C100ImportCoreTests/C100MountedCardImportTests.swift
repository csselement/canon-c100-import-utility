import XCTest
@testable import C100ImportCore

final class C100MountedCardImportTests: XCTestCase {
    func testMountedCanonCardImportsAndVerifiesWhenEnabled() throws {
        guard ProcessInfo.processInfo.environment["C100_RUN_SD_IMPORT_TEST"] == "1" else {
            throw XCTSkip("Set C100_RUN_SD_IMPORT_TEST=1 to copy and verify the mounted Canon SD card.")
        }

        let source = URL(fileURLWithPath: "/Volumes/CANON", isDirectory: true)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw XCTSkip("No Canon SD card mounted at /Volumes/CANON.")
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("C100MountedCardImport-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: destination)
        }

        let clips = try C100CardScanner().scan(root: source)
        XCTAssertFalse(clips.isEmpty)

        let plans = C100ImportPlanner(destinationRoot: destination).plan(for: clips)
        let results = try C100Importer().importClips(using: plans)

        XCTAssertEqual(results.count, clips.count)
        XCTAssertTrue(results.allSatisfy(\.videoVerification.matchesSource))
        XCTAssertTrue(results.allSatisfy { $0.sidecarVerification?.matchesSource ?? false })
        XCTAssertTrue(results.allSatisfy { $0.plan.videoDestinationURL.deletingLastPathComponent().lastPathComponent.isEightDigitDate })
        XCTAssertTrue(results.allSatisfy { $0.plan.videoDestinationURL.deletingPathExtension().lastPathComponent.isFourteenDigitTimestamp })
    }
}

private extension String {
    var isEightDigitDate: Bool {
        count == 8 && allSatisfy(\.isNumber)
    }

    var isFourteenDigitTimestamp: Bool {
        count == 14 && allSatisfy(\.isNumber)
    }
}
