import XCTest
@testable import MoleKitCore

/// Runs read-only and `--dry-run` commands against the real `mo`.
/// Skipped unless MOLEKIT_LIVE=1, so CI never touches a real Mac.
final class LiveMoleTests: XCTestCase {
    private func cli() throws -> MoleCLI {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MOLEKIT_LIVE"] == "1", "set MOLEKIT_LIVE=1")
        return try XCTUnwrap(MoleCLI.locate(), "mo not installed")
    }

    func testStatus() async throws {
        let out = try await cli().runChecked(["status", "--json"])
        let s = try MoleJSON.decode(StatusSnapshot.self, from: out.stdout)
        XCTAssertNotNil(s.cpu?.usage)
        XCTAssertNotNil(s.rootDisk?.total)
    }

    func testHistory() async throws {
        let out = try await cli().runChecked(["history", "--json", "--limit", "5"])
        _ = try MoleJSON.decode(HistoryResult.self, from: out.stdout)
    }

    func testUninstallList() async throws {
        let out = try await cli().runChecked(["uninstall", "--list"])
        let apps = try MoleJSON.decode([InstalledApp].self, from: out.stdout)
        XCTAssertFalse(apps.isEmpty)
    }

    func testCleanDryRun() async throws {
        let out = try await cli().run(["clean", "--dry-run"])
        XCTAssertEqual(out.status, 0, out.stderr)
        XCTAssertNotNil(SummaryParser.clean(out.stdout), "no summary in: \(out.stdout.suffix(400))")
        let text = try String(contentsOf: CleanListParser.defaultURL, encoding: .utf8)
        XCTAssertFalse(CleanListParser.parse(text).nonEmptySections.isEmpty)
    }

    func testPurgeDryRun() async throws {
        let out = try await cli().run(["purge", "--dry-run"])
        XCTAssertEqual(out.status, 0, out.stderr)
        _ = PurgeParser.parse(out.stdout)
    }

    func testStatusStream() async throws {
        var count = 0
        for try await line in try cli().lines(["status", "--watch", "--interval", "1s"]) {
            _ = try MoleJSON.decode(StatusSnapshot.self, from: line)
            count += 1
            if count == 2 { break }
        }
        XCTAssertEqual(count, 2)
    }
}
