import XCTest
@testable import MoleKitCore

final class WhitelistTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("molekit-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    func testCreatesFileWithDefaultsAndRemovesItAfterwards() throws {
        let session = WhitelistSession(home: home)
        try session.apply(paths: ["/Users/x/Library/Caches/Foo"], defaults: ["/d/one*", "FINDER_METADATA"])
        let text = try String(contentsOf: session.whitelistURL, encoding: .utf8)
        XCTAssertTrue(text.contains("/d/one*"))
        XCTAssertTrue(text.contains("FINDER_METADATA"))
        XCTAssertTrue(text.contains("/Users/x/Library/Caches/Foo"))
        try session.restore()
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.whitelistURL.path))
        XCTAssertFalse(session.hasPendingRestore)
    }

    func testKeepsExistingFileExactly() throws {
        let session = WhitelistSession(home: home)
        try FileManager.default.createDirectory(at: session.whitelistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = "# mine\n/Users/x/keep\n"
        try original.write(to: session.whitelistURL, atomically: true, encoding: .utf8)
        try session.apply(paths: ["/Users/x/skip"], defaults: ["/never/used"])
        let during = try String(contentsOf: session.whitelistURL, encoding: .utf8)
        XCTAssertTrue(during.contains("/Users/x/keep"))
        XCTAssertTrue(during.contains("/Users/x/skip"))
        XCTAssertFalse(during.contains("/never/used"))
        try session.restore()
        XCTAssertEqual(try String(contentsOf: session.whitelistURL, encoding: .utf8), original)
    }

    func testRecoversAfterCrash() throws {
        let first = WhitelistSession(home: home)
        try first.apply(paths: ["/Users/x/skip"], defaults: ["/d"])
        // A new session (e.g. after an app crash) sees the pending restore.
        let second = WhitelistSession(home: home)
        XCTAssertTrue(second.hasPendingRestore)
        try second.restore()
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.whitelistURL.path))
    }

    func testRejectsUnsafeEntries() {
        XCTAssertFalse(WhitelistSession.isSafeEntry("relative/path"))
        XCTAssertFalse(WhitelistSession.isSafeEntry("/a/../b"))
        XCTAssertFalse(WhitelistSession.isSafeEntry("/a/[glob]"))
        XCTAssertTrue(WhitelistSession.isSafeEntry("/Users/x/Library/Caches/com.example"))
    }

    func testReadsMoleDefaults() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MOLEKIT_LIVE"] == "1")
        let cli = try XCTUnwrap(MoleCLI.locate())
        let defaults = await cli.defaultWhitelist()
        XCTAssertNotNil(defaults)
        XCTAssertTrue(defaults?.contains("FINDER_METADATA") == true)
    }
}
