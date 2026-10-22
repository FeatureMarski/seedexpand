import Foundation

public struct Expansion: Equatable, Sendable {
    public let snippetID: String
    /// Number of Swift Characters in the trigger, not bytes of replacement text.
    public let deleteCharacters: Int
    public let text: String
}

/// A pure, bounded matcher. An OS adapter must independently prove focus, field safety,
/// input origin and permission before applying an edit. This type does not grant those rights.
public struct ExpansionEngine: Sendable {
    private let byTrigger: [String: Snippet]
    private let maxLength: Int
    private var buffer = ""
    private var truncatedPredecessorWasWord = false
    public private(set) var paused = false
    public var bufferedCharacters: Int { buffer.count }

    public init(library: Library) throws {
        try library.validate()
        byTrigger = Dictionary(uniqueKeysWithValues: library.snippets.map { ($0.trigger, $0) })
        maxLength = library.snippets.map { $0.trigger.count }.max() ?? 0
    }
    public mutating func reset() {
        buffer = ""; truncatedPredecessorWasWord = false
    }
    public mutating func setPaused(_ value: Bool) {
        paused = value; reset()
    }
    public mutating func backspace() {
        if !buffer.isEmpty { buffer.removeLast() }
    }
    /// Pass one user-committed grapheme at a time. Bulk paste/IME batches reset matching.
    public mutating func feed(_ input: String, secure: Bool = false) -> Expansion? {
        guard !paused, !secure, input.count == 1, maxLength > 0 else { reset(); return nil }
        guard !input.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            reset(); return nil
        }
        buffer += input
        while buffer.count > maxLength + 1 {
            truncatedPredecessorWasWord = Self.isWord(buffer.removeFirst())
        }
        // Most inputs are not triggers. Dictionary lookup keeps the common path bounded.
        let chars = Array(buffer)
        for start in chars.indices {
            let candidate = String(chars[start...])
            guard let snippet = byTrigger[candidate] else { continue }
            let precededByWord = start == 0 ? truncatedPredecessorWasWord : Self.isWord(chars[start - 1])
            guard !precededByWord else { continue }
            reset()
            return Expansion(snippetID: snippet.id, deleteCharacters: candidate.count, text: snippet.text)
        }
        return nil
    }
    private static func isWord(_ character: Character) -> Bool {
        character == "_" || character.unicodeScalars.contains {
            CharacterSet.alphanumerics.contains($0) || CharacterSet.nonBaseCharacters.contains($0)
        }
    }
}
