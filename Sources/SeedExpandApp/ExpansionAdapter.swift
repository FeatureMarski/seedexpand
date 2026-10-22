import AppKit
import ApplicationServices
import Carbon
import SeedExpandCore

/// Listen-only monitoring. Every attempt re-reads the complete target state and fails closed.
@MainActor final class ExpansionAdapter: ObservableObject {
    @Published var enabled = false
    @Published var paused = true { didSet { continuity.reset() } }
    @Published var status = "Monitoring off. Copy works without permissions."
    var library = Library(snippets: [])
    var exclusions: Set<String> = []
    private var monitor: Any?
    private var continuity = FocusContinuity()
    private var previousElement: AXUIElement?
    var accessibility: Bool { AXIsProcessTrusted() }
    var inputMonitoring: Bool { CGPreflightListenEventAccess() }

    func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestListenEventAccess()
        status = "Grant Accessibility and Input Monitoring in System Settings, then enable monitoring."
    }
    func start() {
        stop()
        guard accessibility, inputMonitoring else { status = "Permissions missing. Use Copy or review permissions."; return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            // Event data is never retained or logged. Modified keys and navigation do not expand.
            let allowed = event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            let textKey = !(event.characters ?? "").isEmpty && ![36, 48, 51, 53, 76, 117, 123, 124, 125, 126].contains(Int(event.keyCode))
            let committed = event.characters ?? ""
            let eventPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let timestamp = event.timestamp
            Task { @MainActor in
                guard allowed, textKey, committed.count == 1,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == eventPID,
                      ProcessInfo.processInfo.systemUptime - timestamp < 0.15 else { self?.continuity.reset(); return }
                self?.attempt(committed: committed)
            }
        }
        enabled = monitor != nil
        paused = !enabled
        status = enabled ? "Ready for supported editable text fields." : "Could not start monitoring. Use Copy."
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; enabled = false; paused = true
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    private struct Snapshot {
        let element: AXUIElement
        let pid: pid_t
        let value: String
        let range: CFRange
    }
    private func snapshot() -> Snapshot? {
        guard enabled, !paused, accessibility, inputMonitoring, !IsSecureEventInputEnabled(),
              let app = NSWorkspace.shared.frontmostApplication,
              let bundle = app.bundleIdentifier, bundle != Bundle.main.bundleIdentifier,
              !exclusions.contains(bundle) else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.05)
        guard let raw = attribute(application, kAXFocusedUIElementAttribute),
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let element = unsafeBitCast(raw, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(element, 0.05)
        guard let role = attribute(element, kAXRoleAttribute) as? String,
              [kAXTextFieldRole, kAXTextAreaRole].contains(role),
              let subrole = attribute(element, kAXSubroleAttribute) as? String,
              subrole != kAXSecureTextFieldSubrole,
              (attribute(element, kAXEnabledAttribute) as? Bool) == true,
              let value = attribute(element, kAXValueAttribute) as? String,
              value.utf8.count <= Library.maxTextBytes,
              let rawRange = attribute(element, kAXSelectedTextRangeAttribute),
              CFGetTypeID(rawRange) == AXValueGetTypeID() else { return nil }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success,
              settable.boolValue else { return nil }
        let axRange = unsafeBitCast(rawRange, to: AXValue.self)
        var range = CFRange()
        guard AXValueGetValue(axRange, .cfRange, &range), range.length == 0 else { return nil }
        return Snapshot(element: element, pid: app.processIdentifier, value: value, range: range)
    }
    private func attempt(committed: String) {
        guard let before = snapshot() else {
            continuity.reset(); previousElement = nil
            status = "Target uncertain or excluded. Use Copy."; return
        }
        if previousElement == nil || !CFEqual(previousElement!, before.element) { continuity.reset() }
        previousElement = before.element
        guard continuity.advance(identity: String(before.pid), caret: before.range.location,
                                 committedUTF16: committed.utf16.count, safe: true),
              before.value.prefixUTF16(before.range.location).hasSuffix(committed) else { return }
        // Feed only a bounded suffix into the existing matcher; retain no typing history.
        guard var engine = try? ExpansionEngine(library: library) else { return }
        let limit = (library.snippets.map { $0.trigger.count }.max() ?? 0) + 1
        var match: Expansion?
        for character in before.value.prefixUTF16(before.range.location).suffix(limit) {
            match = engine.feed(String(character))
        }
        guard let match, let snippet = library.snippets.first(where: { $0.id == match.snippetID }),
              let replacement = InsertionPolicy.replacingTrigger(value: before.value,
                selection: NSRange(location: before.range.location, length: before.range.length),
                trigger: snippet.trigger, replacement: match.text, safe: true),
              replacement.utf8.count <= Library.maxTextBytes,
              let now = snapshot(), now.pid == before.pid, CFEqual(now.element, before.element),
              now.value == before.value, now.range.location == before.range.location,
              now.range.length == before.range.length else { return }
        let result = AXUIElementSetAttributeValue(now.element, kAXValueAttribute as CFString, replacement as CFString)
        // Never retry or attempt rollback: the user may have edited after the write.
        paused = true
        status = result == .success
            ? "Text replaced. Paused for review; resume when ready. No automatic undo."
            : "Target refused insertion. Paused; use Copy."
    }
}

private extension String {
    func prefixUTF16(_ length: Int) -> Substring {
        guard let range = Range(NSRange(location: 0, length: length), in: self) else { return self[startIndex..<startIndex] }
        return self[range]
    }
}
