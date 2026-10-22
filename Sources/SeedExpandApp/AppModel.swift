import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SeedExpandCore

@MainActor final class AppModel: ObservableObject {
    @Published var library = Library(snippets: [])
    @Published var message = ""
    @Published var loadFailed = false
    @Published var pendingImport: Library?
    @Published var excludedApps: String = "" {
        didSet {
            adapter.exclusions = Set(excludedApps.split(whereSeparator: { $0.isWhitespace }).map(String.init))
            UserDefaults.standard.set(excludedApps, forKey: "excludedApps")
        }
    }
    let adapter = ExpansionAdapter()
    let store: PrivateStore
    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SeedExpand", isDirectory: true)
        store = PrivateStore(directory: directory)
        excludedApps = UserDefaults.standard.string(forKey: "excludedApps") ?? ""
        adapter.exclusions = Set(excludedApps.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        reload()
    }
    func reload() {
        do { library = try store.load(); adapter.library = library; loadFailed = false; message = "Library loaded." }
        catch { loadFailed = true; adapter.stop(); message = "Library could not be read. No changes saved. Restore library.json from library.backup.json while the app is closed, then Retry." }
    }
    func persist(_ updated: Library) {
        guard !loadFailed else { return }
        do { try store.save(updated); library = updated; adapter.library = updated; message = "Saved privately." }
        catch { adapter.stop(); message = "Save failed. Previous library remains available; retry after checking storage." }
    }
    func save(_ snippet: Snippet) {
        var updated = library
        if let index = updated.snippets.firstIndex(where: { $0.id == snippet.id }) { updated.snippets[index] = snippet }
        else { updated.snippets.append(snippet) }
        do { try updated.validate(); persist(updated) } catch { message = String(describing: error) }
    }
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        message = "Copied by request. Clipboard is not restored automatically."
    }
    func previewImport() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json, .propertyList]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try PrivateStore.readBounded(url)
            pendingImport = try url.pathExtension.lowercased() == "plist" ? Library.importApplePlist(data) : Library.decodeJSON(data)
        } catch { message = "Import rejected: \(error)" }
    }
    func mergeImport() {
        guard let imported = pendingImport else { return }
        let updated = Library(snippets: library.snippets + imported.snippets)
        do { try updated.validate(); persist(updated); pendingImport = nil }
        catch { message = "Merge refused: \(error). Edit conflicting IDs or triggers in the source file." }
    }
    func export(apple: Bool = false, text: String? = nil) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = text != nil ? "prompt.txt" : apple ? "SeedExpand.plist" : "SeedExpand.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try text.map { Data($0.utf8) } ?? (apple ? library.exportApplePlist() : library.encodeJSON())
            try PrivateStore.writeNew(data, to: url)
            message = apple ? "Exported. Import this plist yourself in macOS Keyboard Text Replacements; no system settings were changed." : "Exported."
        } catch { message = "Export failed: \(error)" }
    }
}
