import Foundation

/// All offsets use UTF-16, matching Accessibility ranges. No clipboard or key events.
public struct InsertionPolicy {
    public static func replacingTrigger(value: String, selection: NSRange, trigger: String,
                                        replacement: String, safe: Bool) -> String? {
        guard safe, selection.length == 0, selection.location >= 0,
              selection.location <= value.utf16.count,
              !trigger.isEmpty, !replacement.isEmpty else { return nil }
        let end = selection.location
        let start = end - trigger.utf16.count
        guard start >= 0,
              let range = Range(NSRange(location: start, length: end - start), in: value),
              value[range] == trigger else { return nil }
        if range.lowerBound > value.startIndex {
            let before = value[value.index(before: range.lowerBound)]
            guard !before.unicodeScalars.contains(where: {
                CharacterSet.alphanumerics.contains($0) || CharacterSet.nonBaseCharacters.contains($0)
            }), before != "_" else { return nil }
        }
        return value.replacingCharacters(in: range, with: replacement)
    }
}

/// Retains only target identity and caret offset, never typed text.
public struct FocusContinuity: Sendable {
    private var identity: String?
    private var caret: Int?
    public init() {}
    public mutating func reset() { identity = nil; caret = nil }
    public mutating func advance(identity next: String, caret nextCaret: Int,
                                 committedUTF16: Int, safe: Bool) -> Bool {
        guard safe, nextCaret >= 0, committedUTF16 > 0, committedUTF16 <= 8 else { reset(); return false }
        defer { identity = next; caret = nextCaret }
        guard identity == next, let caret else { return false }
        return nextCaret == caret + committedUTF16
    }
}
