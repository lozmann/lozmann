import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Observation

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var created = Date()
    var updated = Date()
    var pinned = false

    var title: String {
        let first = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let t = first.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "Yeni not" : t
    }

    var preview: String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).dropFirst()
        return lines.prefix(2).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}

@Observable
final class NotesStore {
    static let shared = NotesStore()

    var notes: [Note] = []

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("notes.json")

    private init() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            notes = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notes) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func replaceAll(_ newNotes: [Note]) {
        notes = newNotes
        save()
    }

    @discardableResult
    func add(_ text: String = "") -> UUID {
        let note = Note(text: text)
        notes.insert(note, at: 0)
        save()
        return note.id
    }

    func setText(_ id: UUID, _ text: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }), notes[i].text != text else { return }
        notes[i].text = text
        notes[i].updated = Date()
        save()
    }

    func togglePin(_ id: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].pinned.toggle()
        save()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    func removeIfEmpty(_ id: UUID) {
        if let n = notes.first(where: { $0.id == id }), n.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            delete(id)
        }
    }

    var sorted: [Note] {
        notes.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.updated > b.updated
        }
    }
}

struct NoteRoute: Hashable {
    let id: UUID
}

struct NotesView: View {
    @Environment(NotesStore.self) private var store
    @State private var search = ""
    @State private var path: [NoteRoute] = []
    @State private var importing = false
    @State private var showHelp = false
    @State private var message: String?

    var body: some View {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased(with: Locale(identifier: "tr_TR"))
        let list = store.sorted.filter { q.isEmpty || $0.text.lowercased(with: Locale(identifier: "tr_TR")).contains(q) }

        NavigationStack(path: $path) {
            List {
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if store.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Henüz not yok").font(.headline)
                        Text("Sağ üstten yeni not yaz ya da iPhone'daki Notlar uygulamasından notlarını aktar.")
                            .foregroundStyle(.secondary)
                        Button("Notlarımı nasıl aktarırım?") { showHelp = true }
                    }
                    .padding(.vertical, 6)
                } else if list.isEmpty {
                    Text("Aramana uyan not yok.").foregroundStyle(.secondary)
                }
                ForEach(list) { note in
                    NavigationLink(value: NoteRoute(id: note.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                if note.pinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.loz)
                                }
                                Text(note.title).font(.headline).lineLimit(1)
                            }
                            HStack(spacing: 6) {
                                Text(shortDate(note.updated))
                                if !note.preview.isEmpty {
                                    Text(note.preview).lineLimit(1)
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { store.delete(note.id) } label: { Label("Sil", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        Button { store.togglePin(note.id) } label: {
                            Label(note.pinned ? "Sabitlemeyi kaldır" : "Sabitle", systemImage: note.pinned ? "pin.slash" : "pin")
                        }
                        .tint(.loz)
                    }
                }
            }
            .navigationTitle("Notlar")
            .searchable(text: $search, prompt: "Notlarda ara")
            .navigationDestination(for: NoteRoute.self) { route in
                NoteEditor(id: route.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            pasteNote()
                        } label: {
                            Label("Panodan yapıştır", systemImage: "doc.on.clipboard")
                        }
                        Button {
                            importing = true
                        } label: {
                            Label("Metin dosyalarından aktar", systemImage: "doc.text")
                        }
                        Button {
                            showHelp = true
                        } label: {
                            Label("Notlar uygulamasından aktarma", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Label("İçe aktar", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let id = store.add()
                        path.append(NoteRoute(id: id))
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Yeni not")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, .text, .utf8PlainText], allowsMultipleSelection: true) { result in
                importFiles(result)
            }
            .sheet(isPresented: $showHelp) {
                ImportHelpView()
            }
        }
    }

    private func shortDate(_ d: Date) -> String {
        let k = Day.key(d)
        let diff = Day.diff(k)
        if diff == 0 {
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        }
        if diff == -1 { return "Dün" }
        let p = Day.parts(k)
        return "\(p.day) \(Day.shortMonths[p.month])"
    }

    private func pasteNote() {
        guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = "Panoda metin yok. Notlar uygulamasında notu açıp Paylaş → Kopyala de, sonra tekrar dene."
            return
        }
        store.add(text)
        message = "Not panodan eklendi."
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else {
            message = "Dosyalar açılamadı."
            return
        }
        var count = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let text = try? String(contentsOf: url, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let name = url.deletingPathExtension().lastPathComponent
                let firstLine = text.split(separator: "\n").first.map(String.init) ?? ""
                let body = firstLine.trimmingCharacters(in: .whitespaces) == name ? text : name + "\n" + text
                store.add(body)
                count += 1
            }
        }
        message = count == 0 ? "Aktarılacak metin bulunamadı." : "\(count) not aktarıldı."
    }
}

struct NoteEditor: View {
    @Environment(NotesStore.self) private var store
    let id: UUID
    @State private var text = ""
    @State private var loaded = false
    @FocusState private var focused: Bool

    var body: some View {
        let note = store.notes.first { $0.id == id }
        TextEditor(text: $text)
            .focused($focused)
            .padding(.horizontal, 12)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(note?.title ?? "Not")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if let note {
                        Button {
                            store.togglePin(id)
                        } label: {
                            Image(systemName: note.pinned ? "pin.fill" : "pin")
                        }
                        .accessibilityLabel(note.pinned ? "Sabitlemeyi kaldır" : "Sabitle")
                        ShareLink(item: text) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    if focused {
                        Button("Bitti") { focused = false }
                    }
                }
            }
            .onAppear {
                if !loaded {
                    text = note?.text ?? ""
                    loaded = true
                    if text.isEmpty { focused = true }
                }
            }
            .onChange(of: text) { _, newValue in
                if loaded { store.setText(id, newValue) }
            }
            .onDisappear {
                store.removeIfEmpty(id)
            }
    }
}

struct ImportHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Tek tek aktarma (en kolayı)") {
                    Label("Notlar uygulamasında notu aç", systemImage: "1.circle.fill")
                    Label("Sağ üstteki ⋯ veya Paylaş'a dokun, Kopyala'yı seç", systemImage: "2.circle.fill")
                    Label("Lozman'da Notlar → İçe aktar → Panodan yapıştır", systemImage: "3.circle.fill")
                }
                Section("Metin dosyası olarak") {
                    Text("Bir notu Paylaş → Dosyalar'a Kaydet ile metin dosyası olarak kaydettiysen, İçe aktar → Metin dosyalarından aktar ile birden fazla dosyayı birlikte seçebilirsin.")
                }
                Section {
                    Text("iPhone, Notlar uygulamasındaki tüm notları başka bir uygulamanın tek seferde okumasına izin vermiyor. Bu yüzden notlar tek tek aktarılıyor.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Notları aktar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tamam") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
