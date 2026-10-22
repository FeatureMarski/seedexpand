import SwiftUI
import AppKit
import SeedExpandCore

@main struct SeedExpandApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        MenuBarExtra("SeedExpand", systemImage: "text.badge.plus") {
            MenuControls(model: model, adapter: model.adapter)
        }
        Window("SeedExpand Library", id: "library") {
            LibraryView(model: model, adapter: model.adapter)
                .frame(minWidth: 800, minHeight: 620)
        }
    }
}

struct MenuControls: View {
    @ObservedObject var model: AppModel
    @ObservedObject var adapter: ExpansionAdapter
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Library, Copy and Settings") { openWindow(id: "library"); NSApp.activate(ignoringOtherApps: true) }
        Button(adapter.paused ? "Resume" : "Pause") {
            if adapter.enabled { adapter.paused.toggle() } else { openWindow(id: "library") }
        }.disabled(model.loadFailed)
        Text(adapter.status)
        Divider()
        Button("Quit SeedExpand") { NSApp.terminate(nil) }
    }
}

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var adapter: ExpansionAdapter
    @State private var search = ""
    @State private var draft = Snippet(title: "", trigger: "", text: "")
    @State private var blocks: [String] = []
    @State private var showAdvanced = false
    private var validation: String? {
        var updated = model.library
        updated.snippets.removeAll { $0.id == draft.id }; updated.snippets.append(draft)
        do { try updated.validate(); return nil } catch { return String(describing: error) }
    }
    private var composition: String { (try? model.library.compose(ids: blocks)) ?? "" }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SeedExpand").font(.title)
                Spacer()
                Button(adapter.paused ? "Resume" : "Pause") { adapter.paused.toggle() }
                    .disabled(!adapter.enabled || model.loadFailed)
                Button("Stop Monitoring") { adapter.stop() }.disabled(!adapter.enabled)
            }
            Text(adapter.status).font(.caption)
            HSplitView {
                VStack(alignment: .leading) {
                    TextField("Search title, trigger or text", text: $search)
                    List {
                        ForEach(model.library.snippets.filter { search.isEmpty || "\($0.title) \($0.trigger) \($0.text)".localizedCaseInsensitiveContains(search) }, id: \.id) { snippet in
                            Button { draft = snippet } label: {
                                VStack(alignment: .leading) { Text(snippet.title.isEmpty ? snippet.trigger : snippet.title); Text(snippet.trigger).font(.caption) }
                            }.buttonStyle(.plain)
                        }
                    }
                    Button("New Shortcut") { draft = Snippet(title: "", trigger: "", text: "") }
                }.frame(minWidth: 220)
                VStack(alignment: .leading) {
                    TextField("Title", text: $draft.title)
                    TextField("Trigger, e.g. ;hello", text: $draft.trigger)
                    Text("Text").font(.headline)
                    TextEditor(text: $draft.text).frame(minHeight: 120)
                    Text("Preview").font(.headline)
                    ScrollView { Text(draft.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 90)
                    if let validation { Text(validation).foregroundColor(.red).font(.caption) }
                    HStack {
                        Button("Save") { model.save(draft) }.disabled(validation != nil || model.loadFailed)
                        Button("Copy Preview") { model.copy(draft.text) }.disabled(draft.text.isEmpty)
                        Button("Delete") {
                            var updated = model.library; updated.snippets.removeAll { $0.id == draft.id }; model.persist(updated)
                            draft = Snippet(title: "", trigger: "", text: "")
                        }.disabled(model.loadFailed || !model.library.snippets.contains { $0.id == draft.id })
                    }
                }.padding(.leading, 10).frame(minWidth: 420)
            }
            Text(model.message).font(.caption).textSelection(.enabled)
            if model.loadFailed { Button("Retry Loading") { model.reload() } }
            HStack {
                Button("Preview Import") { model.previewImport() }.disabled(model.loadFailed)
                Button("Export JSON") { model.export() }
                Button("Export Apple plist") { model.export(apple: true) }
            }
            if let imported = model.pendingImport {
                GroupBox("Import preview: \(imported.snippets.count) shortcuts. Existing library stays intact; conflicts refuse the whole merge.") {
                    VStack(alignment: .leading) {
                        ScrollView { ForEach(imported.snippets, id: \.id) { s in VStack(alignment: .leading) { Text("\(s.trigger): \(s.title)"); Text(s.text) }.textSelection(.enabled) } }.frame(height: 65)
                        HStack { Button("Merge with Backup") { model.mergeImport() }; Button("Cancel") { model.pendingImport = nil } }
                    }
                }
            }
            DisclosureGroup("Composition, permissions and diagnostics", isExpanded: $showAdvanced) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ordered blocks: add saved shortcuts, move them, then preview and copy. No AI service.")
                        HStack {
                            Menu("Add Block") { ForEach(model.library.snippets, id: \.id) { s in Button(s.title.isEmpty ? s.trigger : s.title) { blocks.append(s.id) } } }
                            Button("Clear Blocks") { blocks = [] }
                            Button("Copy Composition") { model.copy(composition) }.disabled(composition.isEmpty)
                            Button("Export Composition") { model.export(text: composition) }.disabled(composition.isEmpty)
                        }
                        ForEach(Array(blocks.enumerated()), id: \.offset) { index, id in
                            HStack {
                                Text("\(index + 1). \(model.library.snippets.first(where: { $0.id == id })?.title ?? "Missing block")")
                                Button("Up") { blocks.swapAt(index, index - 1) }.disabled(index == 0)
                                Button("Remove") { blocks.remove(at: index) }
                            }
                        }
                        Text(composition.isEmpty ? "Choose valid blocks (maximum 1 MiB output)." : composition).textSelection(.enabled)
                        Divider()
                        Text("Copy needs no permission. Optional automatic expansion needs Accessibility to inspect and replace editable text, and Input Monitoring for key-up notifications. No screen recording. Monitoring starts only with Enable. Secure, excluded or uncertain fields are refused. Each insertion pauses for review. Undo is unavailable; use the editor's own undo only after checking its behavior.")
                        HStack {
                            Button("Request Permissions") { adapter.requestPermissions() }
                            Button("Enable Monitoring") { adapter.start() }.disabled(model.loadFailed)
                        }
                        TextField("Excluded app bundle IDs, separated by spaces", text: $model.excludedApps)
                        Text("Accessibility: \(adapter.accessibility ? "granted" : "missing"); Input Monitoring: \(adapter.inputMonitoring ? "granted" : "missing"); monitoring: \(adapter.enabled ? "on" : "off"); paused: \(adapter.paused ? "yes" : "no"). No typing logs or telemetry.")
                        Text("Support is optional. No donation endpoint is enabled; all features remain free.").font(.caption)
                    }
                }.frame(maxHeight: 230)
            }
        }.padding()
    }
}
