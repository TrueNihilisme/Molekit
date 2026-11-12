import XCTest
@testable import MoleKitCore

// Fixtures follow the formats printed by mo 1.71. Paths are made up.
final class ParserTests: XCTestCase {
    func testByteSizeParse() {
        XCTAssertEqual(ByteSize.parse("16.27GB"), 16_270_000_000)
        XCTAssertEqual(ByteSize.parse("222.7MB"), 222_700_000)
        XCTAssertEqual(ByteSize.parse("4KB"), 4_000)
        XCTAssertEqual(ByteSize.parse("64B"), 64)
        XCTAssertNil(ByteSize.parse("--"))
    }

    func testByteSizeFormat() {
        XCTAssertEqual(ByteSize.format(12_380_000_000, language: "en"), "12.4 GB")
        XCTAssertEqual(ByteSize.format(12_380_000_000, language: "uk"), "12,4 ГБ")
        XCTAssertEqual(ByteSize.format(512, language: "en"), "512 B")
    }

    func testCleanList() {
        let text = """
        # Mole Cleanup Preview - 2026-01-01 10:00:00
        #
        # How to protect files:

        === User essentials ===
        /Users/example/Library/Caches  # 222.7MB, 3 items
        /Users/example/Library/Logs/CoreSimulator  # 4KB

        === Browsers ===
        /Users/example/Library/Caches/Google/Chrome/Default  # 192.6MB

        === Virtualization ===

        # ============================================
        # Summary
        # ============================================
        # Potential cleanup: 415.3MB
        # Items: 4
        # Categories: 3
        """
        let preview = CleanListParser.parse(text)
        XCTAssertEqual(preview.sections.map(\.title), ["User essentials", "Browsers", "Virtualization"])
        XCTAssertEqual(preview.nonEmptySections.count, 2)
        XCTAssertEqual(preview.sections[0].items.count, 2)
        XCTAssertEqual(preview.sections[0].items[0].count, 3)
        XCTAssertEqual(preview.sections[0].items[0].bytes, 222_700_000)
        XCTAssertEqual(preview.reportedTotal, 415_300_000)
        XCTAssertEqual(preview.reportedItems, 4)
    }

    func testCleanSummary() {
        XCTAssertEqual(SummaryParser.clean("Cleanup complete\nRemoved: 12.26GB · 2397 items\nFree space: 35.72GB"),
                       RunSummary(bytes: 12_260_000_000, items: 2397))
        XCTAssertEqual(SummaryParser.clean("Potential space: 12.38GB · 2622 items")?.bytes, 12_380_000_000)
    }

    func testPurge() {
        let out = """
        ○ DRY RUN MODE, No project artifacts will be removed
        ✓ [DRY RUN] ~/projects/app/node_modules, 106.3MB
        ✓ [DRY RUN] ~/projects/tool/.venv, 123.7MB
        Would free approximately: 230.0MB | Items: 2 | Free: 23.42GB
        """
        let preview = PurgeParser.parse(out)
        XCTAssertEqual(preview.items.count, 2)
        XCTAssertEqual(preview.items[0].kind, "node_modules")
        XCTAssertTrue(preview.items[1].needsManualRestore)
        XCTAssertEqual(preview.reportedTotal, 230_000_000)
    }

    func testStatusJSON() throws {
        let json = """
        {"uptime":"1d 2h","hardware":{"model":"MacBook Air","cpu_model":"Apple M4","total_ram":"16.0 GB"},
         "health_score":100,"health_score_msg":"Excellent",
         "cpu":{"usage":21.5,"per_core":[10,20],"load1":2.8,"core_count":10,"p_core_count":4,"e_core_count":6},
         "memory":{"used":11000000000,"total":16000000000,"used_percent":65.5,"pressure":"normal"},
         "disks":[{"mount":"/","used":170000000000,"total":245000000000,"used_percent":69.4,"smart_status":"verified"}],
         "batteries":[{"percent":79,"status":"discharging","time_left":"9:37","health":"Good","cycle_count":146}],
         "top_processes":[{"pid":1,"name":"WindowServer","cpu":40.8,"memory_bytes":140000000}],
         "something_new":{"ignored":true}}
        """
        let s = try MoleJSON.decode(StatusSnapshot.self, from: json)
        XCTAssertEqual(s.hardware?.cpuModel, "Apple M4")
        XCTAssertEqual(s.cpu?.pCoreCount, 4)
        XCTAssertEqual(s.rootDisk?.smartStatus, "verified")
        XCTAssertEqual(s.topProcesses?.first?.name, "WindowServer")
    }

    func testHistoryJSON() throws {
        let json = """
        {"logs":{},"limit":2,"sessions":[
          {"command":"clean","started_at":"2026-01-01 21:36:00","items":2397,"size":"12.26GB","actions":{"removed":2623,"trashed":0}},
          {"command":"clean-dry-run","started_at":"2026-01-01 21:32:06","items":2622,"size":"12.38GB","actions":{"removed":0}}]}
        """
        let h = try MoleJSON.decode(HistoryResult.self, from: json)
        XCTAssertEqual(h.sessions?.count, 2)
        XCTAssertFalse(h.sessions![0].isPreview)
        XCTAssertTrue(h.sessions![1].isPreview)
        XCTAssertEqual(h.sessions![1].baseCommand, "clean")
        XCTAssertEqual(h.sessions![0].sizeBytes, 12_260_000_000)
    }

    func testAnalyzeJSON() throws {
        let json = """
        {"scan_status":"partial","path":"/","overview":true,"entries":[
          {"name":"User Library","path":"/Users/example/Library","size":46544429056,"is_dir":true,"scan_status":"complete"}],
         "total_size":117041422930}
        """
        let a = try MoleJSON.decode(AnalyzeResult.self, from: json)
        XCTAssertEqual(a.entries?.first?.size, 46_544_429_056)
        XCTAssertEqual(a.totalSize, 117_041_422_930)
    }

    func testANSIStrip() {
        XCTAssertEqual(ANSI.strip("\u{1B}[32m✓\u{1B}[0m done"), "✓ done")
    }

    func testTilde() {
        XCTAssertEqual(PathDisplay.tilde("/Users/a/Library", home: "/Users/a"), "~/Library")
    }
}

final class UpdateTests: XCTestCase {
    func testVersionCompare() {
        XCTAssertTrue(MoleUpdate.isNewer("1.72.0", than: "1.71.0"))
        XCTAssertTrue(MoleUpdate.isNewer("2.0.0", than: "1.99.9"))
        XCTAssertFalse(MoleUpdate.isNewer("1.71.0", than: "1.71.0"))
        XCTAssertFalse(MoleUpdate.isNewer("1.70.9", than: "1.71.0"))
    }

    func testLatestLive() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MOLEKIT_LIVE"] == "1")
        let v = await MoleUpdate.latestVersion(channel: .homebrew)
        XCTAssertNotNil(v)
    }
}
