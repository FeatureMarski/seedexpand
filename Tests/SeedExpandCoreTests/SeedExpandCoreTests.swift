import XCTest
@testable import SeedExpandCore

final class SeedExpandCoreTests: XCTestCase {
    func snippet(_ trigger: String = ";hello", _ text: String = "Hello!") -> Snippet {
        Snippet(id: trigger, title: trigger, trigger: trigger, text: text)
    }
    func library(_ trigger: String = ";hello", _ text: String = "Hello!") -> Library {
        Library(snippets: [snippet(trigger, text)])
    }
    func feed(_ text: String, to engine: inout ExpansionEngine) -> [Expansion] {
        text.compactMap { engine.feed(String($0)) }
    }
    func testValidLibrary() throws { try library().validate() }
    func testEmptyLibrary() throws { try Library(snippets: []).validate() }
    func testVersionRejected() { XCTAssertThrowsError(try Library(snippets: [], version: 2).validate()) }
    func testDuplicateIDRejected() {
        XCTAssertThrowsError(try Library(snippets: [snippet(), Snippet(id: ";hello", title: "x", trigger: ";other", text: "x")]).validate())
    }
    func testDuplicateTriggerRejected() {
        XCTAssertThrowsError(try Library(snippets: [snippet(), Snippet(id: "unique", title: "x", trigger: ";hello", text: "x")]).validate())
    }
    func testPrefixCollisionRejected() {
        XCTAssertThrowsError(try Library(snippets: [snippet(";a"), snippet(";abc")]).validate())
    }
    func testWhitespaceTriggerRejected() { XCTAssertThrowsError(try library("a b").validate()) }
    func testNonASCIITriggerRejected() { XCTAssertThrowsError(try library(";cafe\u{301}").validate()) }
    func testLongTriggerRejected() { XCTAssertThrowsError(try library(String(repeating: "a", count: 65)).validate()) }
    func testEmptyTextRejected() { XCTAssertThrowsError(try library(";x", "").validate()) }
    func testNULRejected() { XCTAssertThrowsError(try library(";x", "a\0b").validate()) }
    func testUnicodeTextPreserved() throws {
        let value = library(";u", "Cafe\u{301} 👩🏽‍💻\nالعربية\n日本語")
        XCTAssertEqual(try Library.decodeJSON(value.encodeJSON()), value)
    }
    func testLongPromptRoundTrip() throws {
        let value = library(";prompt", String(repeating: "a<&>\n", count: 10_000))
        let result = try Library.importApplePlist(value.exportApplePlist())
        XCTAssertEqual(result.snippets.first?.text, value.snippets.first?.text)
    }
    func testMalformedJSONRejected() { XCTAssertThrowsError(try Library.decodeJSON(Data("{}".utf8))) }
    func testMalformedPlistRejected() { XCTAssertThrowsError(try Library.importApplePlist(Data("not a plist".utf8))) }
    func testPlistMissingKeyRejected() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: [["shortcut": ";x"]], format: .xml, options: 0)
        XCTAssertThrowsError(try Library.importApplePlist(data))
    }
    func testPlistRoundTrip() throws {
        let result = try Library.importApplePlist(library().exportApplePlist())
        XCTAssertEqual(result.snippets.first?.trigger, ";hello")
        XCTAssertEqual(result.snippets.first?.text, "Hello!")
    }
    func testComposeOrderAndSeparator() throws {
        let value = Library(snippets: [snippet(";a", "One"), snippet(";b", "Two")])
        XCTAssertEqual(try value.compose(ids: [";b", ";a"], separator: " | "), "Two | One")
    }
    func testUnknownBlockRejected() { XCTAssertThrowsError(try library().compose(ids: ["missing"])) }
    func testEmptyCompositionRejected() { XCTAssertThrowsError(try library().compose(ids: [])) }
    func testSimpleExpansion() throws {
        var engine = try ExpansionEngine(library: library())
        let result = feed(";hello", to: &engine)
        XCTAssertEqual(result.count, 1); XCTAssertEqual(result.first?.text, "Hello!")
        XCTAssertEqual(result.first?.deleteCharacters, 6)
    }
    func testWordBoundary() throws {
        var engine = try ExpansionEngine(library: library())
        XCTAssertTrue(feed("word;hello", to: &engine).isEmpty)
        XCTAssertEqual(feed(" ;hello", to: &engine).count, 1)
    }
    func testNoExpansionInsideUnicodeWord() throws {
        var engine = try ExpansionEngine(library: library())
        XCTAssertTrue(feed("é;hello", to: &engine).isEmpty)
    }
    func testSecureInputClearsBuffer() throws {
        var engine = try ExpansionEngine(library: library())
        _ = feed(";hel", to: &engine)
        XCTAssertNil(engine.feed("l", secure: true)); XCTAssertEqual(engine.bufferedCharacters, 0)
        XCTAssertTrue(feed("o", to: &engine).isEmpty)
    }
    func testPauseClearsAndResumes() throws {
        var engine = try ExpansionEngine(library: library())
        engine.setPaused(true); XCTAssertTrue(feed(";hello", to: &engine).isEmpty)
        engine.setPaused(false); XCTAssertEqual(feed(";hello", to: &engine).count, 1)
    }
    func testBulkInputResets() throws {
        var engine = try ExpansionEngine(library: library())
        _ = feed(";hel", to: &engine); XCTAssertNil(engine.feed("lo")); XCTAssertEqual(engine.bufferedCharacters, 0)
    }
    func testFocusResetContract() throws {
        var engine = try ExpansionEngine(library: library())
        _ = feed(";hel", to: &engine); engine.reset()
        XCTAssertTrue(feed("lo", to: &engine).isEmpty)
    }
    func testBackspace() throws {
        var engine = try ExpansionEngine(library: library())
        _ = feed(";heX", to: &engine); engine.backspace()
        XCTAssertEqual(feed("llo", to: &engine).count, 1)
    }
    func testBoundedBuffer() throws {
        var engine = try ExpansionEngine(library: library())
        XCTAssertTrue(feed(String(repeating: "a", count: 10_000), to: &engine).isEmpty)
        XCTAssertLessThanOrEqual(engine.bufferedCharacters, 7)
        XCTAssertTrue(feed(";hello", to: &engine).isEmpty)
    }
    func testNoRecursiveExpansion() throws {
        var engine = try ExpansionEngine(library: library(";x", ";x"))
        XCTAssertEqual(feed(";x", to: &engine).count, 1); XCTAssertEqual(engine.bufferedCharacters, 0)
    }
    func testEmptyEngine() throws {
        var engine = try ExpansionEngine(library: Library(snippets: []))
        XCTAssertTrue(feed("anything", to: &engine).isEmpty); XCTAssertEqual(engine.bufferedCharacters, 0)
    }
    func testControlInputResets() throws {
        var engine = try ExpansionEngine(library: library())
        _ = feed(";hel", to: &engine); XCTAssertNil(engine.feed("\n")); XCTAssertEqual(engine.bufferedCharacters, 0)
    }
}
