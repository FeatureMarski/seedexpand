import XCTest
@testable import SeedExpandCore

final class NativePolicyTests: XCTestCase {
    func testUnicodeInsertionPreservesSurroundings() {
        let value = "🙂 ;hi tail"
        XCTAssertEqual(InsertionPolicy.replacingTrigger(value: value, selection: NSRange(location: 6, length: 0), trigger: ";hi", replacement: "你好\n🌱", safe: true), "🙂 你好\n🌱 tail")
    }
    func testUnsafeSelectionAndUnicodeBoundaryRefused() {
        for range in [NSRange(location: 1, length: 0), NSRange(location: 99, length: 0), NSRange(location: 3, length: 1)] {
            XCTAssertNil(InsertionPolicy.replacingTrigger(value: "🙂;a", selection: range, trigger: ";a", replacement: "x", safe: true))
        }
        XCTAssertNil(InsertionPolicy.replacingTrigger(value: ";a", selection: NSRange(location: 2, length: 0), trigger: ";a", replacement: "x", safe: false))
        XCTAssertNil(InsertionPolicy.replacingTrigger(value: "word;a", selection: NSRange(location: 6, length: 0), trigger: ";a", replacement: "x", safe: true))
        XCTAssertNil(InsertionPolicy.replacingTrigger(value: ";b", selection: NSRange(location: 2, length: 0), trigger: ";a", replacement: "x", safe: true))
    }
    func testContinuityFailsClosed() {
        var gate = FocusContinuity()
        XCTAssertFalse(gate.advance(identity: "a", caret: 1, committedUTF16: 1, safe: true))
        XCTAssertTrue(gate.advance(identity: "a", caret: 2, committedUTF16: 1, safe: true))
        XCTAssertFalse(gate.advance(identity: "b", caret: 3, committedUTF16: 1, safe: true))
        XCTAssertFalse(gate.advance(identity: "b", caret: 3, committedUTF16: 1, safe: true))
        XCTAssertFalse(gate.advance(identity: "b", caret: 4, committedUTF16: 1, safe: false))
        XCTAssertFalse(gate.advance(identity: "b", caret: 5, committedUTF16: 1, safe: true))
        gate.reset()
        XCTAssertFalse(gate.advance(identity: "b", caret: 6, committedUTF16: 1, safe: true))
    }
    func testPrivateStoreRoundtripBackupAndFailure() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PrivateStore(directory: directory)
        XCTAssertEqual(try store.load().snippets.count, 0)
        let first = Library(snippets: [Snippet(id: "a", title: "Synthetic", trigger: ";a", text: "你好")])
        try store.save(first)
        XCTAssertEqual(try store.load(), first)
        try store.save(Library(snippets: []))
        XCTAssertEqual(try Library.decodeJSON(PrivateStore.readBounded(directory.appendingPathComponent("library.backup.json"))), first)
        for name in ["library.json", "library.backup.json"] {
            let attrs = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(name).path)
            XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        }
        XCTAssertThrowsError(try store.save(Library(snippets: [], version: 9)))
        XCTAssertEqual(try store.load().snippets.count, 0)
        try Data("broken".utf8).write(to: store.file)
        XCTAssertThrowsError(try store.load())
    }
    func testExclusiveExportAndSymlinkRefusal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("export.json")
        try PrivateStore.writeNew(Data("original".utf8), to: file)
        XCTAssertThrowsError(try PrivateStore.writeNew(Data("replacement".utf8), to: file))
        XCTAssertEqual(try String(contentsOf: file), "original")
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try PrivateStore.readBounded(link))
    }
}
