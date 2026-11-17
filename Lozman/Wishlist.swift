import SwiftUI
import Observation

struct WishItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var price: String = ""
    var note: String = ""
    var link: String = ""
    var bought = false
    var created = Date()

    /// Reads "1.250", "1250,50", "₺899" and similar as a number.
    var amount: Double? {
        var t = price.filter { $0.isNumber || $0 == "," || $0 == "." }
        guard !t.isEmpty else { return nil }
        if t.contains(",") && t.contains(".") {
            t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else if t.contains(",") {
            t = t.replacingOccurrences(of: ",", with: ".")
        } else if let last = t.split(separator: ".").last, t.contains("."), last.count == 3 {
            t = t.replacingOccurrences(of: ".", with: "")
        }
        return Double(t)
    }
}

@Observable
final class WishStore {
    static let shared = WishStore()

    var items: [WishItem] = []

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("wishlist.json")

    private init() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([WishItem].self, from: data) {
            items = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func replaceAll(_ newItems: [WishItem]) {
        items = newItems
        save()
    }

    func add(_ title: String) {
        items.insert(WishItem(title: title), at: 0)
        save()
    }

    func update(_ item: WishItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i] = item
        save()
    }

    func toggle(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].bought.toggle()
        save()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    static func money(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.numberStyle = .decimal
        f.maximumFractionDigits = v.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return (f.string(from: NSNumber(value: v)) ?? "\(v)") + " ₺"
    }
}

struct WishlistView: View {
    @Environment(WishStore.self) private var store
    @State private var newTitle = ""
    @State private var editing: WishItem?
    @State private var showBought = false
    @FocusState private var addFocused: Bool

    var body: some View {
        let open = store.items.filter { !$0.bought }
        let bought = store.items.filter { $0.bought }
        let total = open.compactMap(\.amount).reduce(0, +)

        List {
            Section {
                HStack {
                    TextField("Ne almak istiyorsun?", text: $newTitle)
                        .focused($addFocused)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Ekle", action: add)
                        .buttonStyle(.borderedProminent)
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Fiyat, not ya da link eklemek için öğeye dokun.")
            }

            Section {
                if open.isEmpty {
                    Text("Listen boş.").foregroundStyle(.secondary)
                }
                ForEach(open) { item in row(item) }
            } header: {
                HStack {
                    Text("Alınacaklar · \(open.count)")
                    Spacer()
                    if total > 0 { Text("Toplam \(WishStore.money(total))") }
                }
            }

            if !bought.isEmpty {
                Section {
                    DisclosureGroup("Aldıklarım · \(bought.count)", isExpanded: $showBought) {
                        ForEach(bought) { item in row(item) }
                    }
                }
            }
        }
        .navigationTitle("Satın alacaklarım")
        .sheet(item: $editing) { item in
            WishEditor(item: item)
        }
    }

    private func add() {
        let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        store.add(t)
        newTitle = ""
        addFocused = true
    }

    private func row(_ item: WishItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { store.toggle(item.id) }
                if !item.bought { Sfx.play("correct"); Sfx.success() }
            } label: {
                Image(systemName: item.bought ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.bought ? Color.loz : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.bought ? "Alınmadı yap" : "Aldım")

            Button {
                editing = item
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .strikethrough(item.bought)
                            .foregroundStyle(item.bought ? Color.secondary : Color.primary)
                        if !item.note.isEmpty {
                            Text(item.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    if let a = item.amount {
                        Text(WishStore.money(a))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if !item.link.isEmpty {
                        Image(systemName: "link").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .swipeActions {
            Button(role: .destructive) { store.delete(item.id) } label: { Label("Sil", systemImage: "trash") }
        }
    }
}

struct WishEditor: View {
    @Environment(WishStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State var item: WishItem

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ne?", text: $item.title)
                    TextField("Fiyat (örn. 1.250)", text: $item.price)
                        .keyboardType(.decimalPad)
                }
                Section("Not") {
                    TextField("Renk, beden, nereden alınacak…", text: $item.note, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("Link") {
                    TextField("https://", text: $item.link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let url = URL(string: item.link.trimmingCharacters(in: .whitespaces)), url.scheme?.hasPrefix("http") == true {
                        Button("Linki aç") { openURL(url) }
                    }
                }
                Section {
                    Toggle("Aldım", isOn: $item.bought)
                }
                Section {
                    Button("Sil", role: .destructive) {
                        store.delete(item.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.update(item)
                        dismiss()
                    }
                    .disabled(item.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
