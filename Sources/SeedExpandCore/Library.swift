import Foundation

public struct Snippet: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var trigger: String
    public var text: String
    public init(id: String = UUID().uuidString, title: String, trigger: String, text: String) {
        self.id = id; self.title = title; self.trigger = trigger; self.text = text
    }
}

public enum LibraryError: Error, Equatable, CustomStringConvertible {
    case invalid(String)
    public var description: String {
        switch self { case .invalid(let message): return message }
    }
}

/// Portable plain-text library. It neither watches keystrokes nor opens a network connection.
public struct Library: Codable, Equatable, Sendable {
    public var version: Int
    public var snippets: [Snippet]
    public static let maxSnippets = 10_000
    public static let maxTextBytes = 1_048_576
    public static let maxLibraryBytes = 16_777_216
    public init(snippets: [Snippet], version: Int = 1) {
        self.version = version; self.snippets = snippets
    }
    public func validate() throws {
        guard version == 1 else { throw LibraryError.invalid("Unsupported library version: \(version)") }
        guard snippets.count <= Self.maxSnippets else { throw LibraryError.invalid("Too many snippets") }
        var ids = Set<String>(), triggers = Set<String>()
        var bytes = 0
        for snippet in snippets {
            guard !snippet.id.isEmpty, snippet.id.utf8.count <= 128 else {
                throw LibraryError.invalid("Snippet ID must contain 1 to 128 UTF-8 bytes")
            }
            guard ids.insert(snippet.id).inserted else { throw LibraryError.invalid("Duplicate snippet ID") }
            guard snippet.title.utf8.count <= 4096 else { throw LibraryError.invalid("Snippet title is too long") }
            let trigger = snippet.trigger
            guard (2...64).contains(trigger.utf8.count),
                  trigger.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 }) else {
                throw LibraryError.invalid("Triggers require 2 to 64 printable ASCII characters without spaces")
            }
            guard triggers.insert(trigger).inserted else { throw LibraryError.invalid("Duplicate trigger: \(trigger)") }
            guard !snippet.text.isEmpty, snippet.text.utf8.count <= Self.maxTextBytes,
                  !snippet.text.unicodeScalars.contains(where: { $0.value == 0 }) else {
                throw LibraryError.invalid("Snippet text is empty, contains NUL, or exceeds 1 MiB")
            }
            bytes += snippet.id.utf8.count + snippet.title.utf8.count + trigger.utf8.count + snippet.text.utf8.count
            guard bytes <= Self.maxLibraryBytes else { throw LibraryError.invalid("Library content exceeds 16 MiB") }
        }
        // Immediate expansion must not consume a shorter trigger before a longer one is typed.
        let sorted = triggers.sorted()
        for index in sorted.indices.dropFirst() where sorted[index].hasPrefix(sorted[index - 1]) {
            throw LibraryError.invalid("Ambiguous trigger prefixes: \(sorted[index - 1]) and \(sorted[index])")
        }
    }
    public static func decodeJSON(_ data: Data) throws -> Library {
        guard data.count <= maxLibraryBytes else { throw LibraryError.invalid("Import exceeds 16 MiB") }
        let result = try JSONDecoder().decode(Library.self, from: data)
        try result.validate()
        return result
    }
    public func encodeJSON() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        guard data.count <= Self.maxLibraryBytes else { throw LibraryError.invalid("Encoded library exceeds 16 MiB") }
        return data
    }
    public func exportApplePlist() throws -> Data {
        try validate()
        let rows = snippets.map { ["shortcut": $0.trigger, "phrase": $0.text] }
        let data = try PropertyListSerialization.data(fromPropertyList: rows, format: .xml, options: 0)
        guard data.count <= Self.maxLibraryBytes else { throw LibraryError.invalid("Export exceeds 16 MiB") }
        return data
    }
    public static func importApplePlist(_ data: Data) throws -> Library {
        guard data.count <= maxLibraryBytes else { throw LibraryError.invalid("Import exceeds 16 MiB") }
        let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let rows = value as? [[String: String]] else {
            throw LibraryError.invalid("Expected an array of phrase/shortcut dictionaries")
        }
        let snippets = try rows.enumerated().map { index, row -> Snippet in
            guard let trigger = row["shortcut"], let text = row["phrase"] else {
                throw LibraryError.invalid("Import row \(index + 1) is missing phrase or shortcut")
            }
            return Snippet(title: trigger, trigger: trigger, text: text)
        }
        let library = Library(snippets: snippets)
        try library.validate()
        return library
    }
    /// Preserve explicit block order. No recursion, code execution, or hidden AI rewriting.
    public func compose(ids: [String], separator: String = "\n\n") throws -> String {
        try validate()
        guard !ids.isEmpty else { throw LibraryError.invalid("Choose at least one block") }
        guard ids.count <= Self.maxSnippets else { throw LibraryError.invalid("Too many blocks") }
        let byID = Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, $0.text) })
        var texts: [String] = [], bytes = 0
        for id in ids {
            guard let text = byID[id] else { throw LibraryError.invalid("Unknown block ID: \(id)") }
            bytes += text.utf8.count + (texts.isEmpty ? 0 : separator.utf8.count)
            guard bytes <= Self.maxTextBytes else { throw LibraryError.invalid("Composed text exceeds 1 MiB") }
            texts.append(text)
        }
        return texts.joined(separator: separator)
    }
}
