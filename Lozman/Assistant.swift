import SwiftUI
import Observation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ChatMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var fromUser: Bool
    var text: String
    var date = Date()
}

enum AIEngine {
    case apple, gemini, none
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
enum AppleEngine {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static var statusText: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Hazır"
        case .unavailable(.deviceNotEligible):
            return "Bu iPhone telefondaki modeli desteklemiyor"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence kapalı. Ayarlar → Apple Intelligence ve Siri'den açabilirsin."
        case .unavailable(.modelNotReady):
            return "Model henüz hazırlanıyor, biraz sonra tekrar dene"
        default:
            return "Şu an kullanılamıyor"
        }
    }

    static func reply(system: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: system)
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
#endif

enum GeminiEngine {
    static let defaultModel = "gemini-flash-lite-latest"
    static let fallbackModel = "gemini-2.5-flash-lite"

    enum Failure: LocalizedError {
        case message(String)
        case modelNotFound
        case rejected(String)
        var errorDescription: String? {
            switch self {
            case .message(let m): return m
            case .modelNotFound: return "Model bulunamadı. Ayarlar'daki Model kutusunu boş bırakıp tekrar dene."
            case .rejected(let m): return "Gemini isteği kabul etmedi. \(m)"
            }
        }
    }

    /// Streams the answer, calling `onText` with the full text so far.
    static func stream(key: String, model: String, system: String, history: [ChatMessage],
                       onText: @escaping @MainActor (String) -> Void) async throws -> String {
        let chosen = model.trimmingCharacters(in: .whitespaces).isEmpty ? defaultModel : model.trimmingCharacters(in: .whitespaces)
        // Try the fast setup first, then plainer requests and other models if Google refuses.
        var plan: [(String, Bool)] = []
        for m in [chosen, fallbackModel, "gemini-flash-latest", "gemini-2.5-flash"] {
            for fast in [true, false] where !plan.contains(where: { $0.0 == m && $0.1 == fast }) {
                plan.append((m, fast))
            }
        }
        var lastError: Error = Failure.modelNotFound
        for (m, fast) in plan {
            do {
                let text = try await attempt(key: key, model: m, system: system, history: history, fast: fast, onText: onText)
                if m != chosen { UserDefaults.standard.set(m, forKey: "geminiModel") }
                return text
            } catch Failure.modelNotFound {
                lastError = Failure.modelNotFound
            } catch Failure.rejected(let msg) {
                lastError = Failure.rejected(msg)
            }
        }
        throw lastError
    }

    private static func attempt(key: String, model: String, system: String, history: [ChatMessage], fast: Bool,
                                onText: @escaping @MainActor (String) -> Void) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse") else {
            throw Failure.modelNotFound
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        let contents: [[String: Any]] = history.map { m in
            ["role": m.fromUser ? "user" : "model", "parts": [["text": m.text]]]
        }
        var config: [String: Any] = ["maxOutputTokens": 800, "temperature": 0.7]
        if fast { config["thinkingConfig"] = ["thinkingBudget": 0] }
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": contents,
            "generationConfig": config
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            var data = Data()
            for try await b in bytes { data.append(b) }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let msg = ((json?["error"] as? [String: Any])?["message"] as? String) ?? ""
            let lower = msg.lowercased()
            if status == 429 { throw Failure.message("Bugünkü ücretsiz kullanım hakkı doldu. Yarın tekrar dene.") }
            if lower.contains("api key") || lower.contains("api_key") || status == 401 || status == 403 {
                throw Failure.message("Gemini anahtarı kabul edilmedi. Ayarlar'da anahtarı başında ve sonunda boşluk olmadan yapıştırdığından emin ol.")
            }
            if status == 404 || lower.contains("not found") { throw Failure.modelNotFound }
            if status == 400 { throw Failure.rejected(msg) }
            throw Failure.message("Gemini'ye ulaşılamadı (kod \(status)). \(msg)")
        }

        var full = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let d = payload.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { continue }
            let candidates = json["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]] ?? []
            let piece = parts.filter { ($0["thought"] as? Bool) != true }.compactMap { $0["text"] as? String }.joined()
            if !piece.isEmpty {
                full += piece
                await onText(full)
            }
        }
        let result = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw Failure.message("Boş cevap geldi, tekrar dene.") }
        return result
    }
}

@Observable
final class AssistantStore {
    static let shared = AssistantStore()

    var messages: [ChatMessage] = []
    var busy = false
    var errorText: String?

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("chat.json")

    private init() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = decoded
        }
    }

    static var geminiKey: String {
        (UserDefaults.standard.string(forKey: "geminiKey") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var geminiModel: String {
        let saved = (UserDefaults.standard.string(forKey: "geminiModel") ?? "").trimmingCharacters(in: .whitespaces)
        return saved.isEmpty ? GeminiEngine.defaultModel : saved
    }

    static var appleAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return AppleEngine.isAvailable }
        #endif
        return false
    }

    static var appleStatus: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return AppleEngine.statusText }
        return "iOS 26 veya daha yenisi gerekli"
        #else
        return "Bu sürümde yok"
        #endif
    }

    var engine: AIEngine {
        if Self.appleAvailable { return .apple }
        if !Self.geminiKey.isEmpty { return .gemini }
        return .none
    }

    private func save() {
        let trimmed = Array(messages.suffix(100))
        if let data = try? JSONEncoder().encode(trimmed) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func clear() {
        messages = []
        errorText = nil
        save()
    }

    private func systemPrompt() -> String {
        let profile = ProfileStore.shared
        let store = PlanStore.shared
        let now = Date()
        let today = Day.today
        let hm = Calendar.current.dateComponents([.hour, .minute], from: now)
        var lines: [String] = []
        for k in 0..<7 {
            let day = Day.add(today, k)
            for p in store.plans(on: day) {
                let status = p.isDone(day) ? " (yapıldı)" : ""
                let time = p.time.isEmpty ? "" : " \(p.time)"
                lines.append("- \(Day.nice(day))\(time): \(p.title) [\(p.category.title)]\(status)")
            }
        }
        let planText = lines.isEmpty ? "Önümüzdeki 7 günde plan yok." : lines.prefix(40).joined(separator: "\n")
        var next = ""
        if let m = BJKStore.shared.nextMatch {
            next = "\nBeşiktaş'ın sıradaki maçı: \(Day.long(m.date)) \(m.time), \(m.home) - \(m.away) (\(m.comp))."
        }
        let name = profile.displayName.isEmpty ? "kullanıcı" : profile.displayName
        return """
        Sen Lozman uygulamasının içindeki kişisel asistansın. Kullanıcının adı \(name).
        Bugün \(Day.long(today)), saat \(String(format: "%02d:%02d", hm.hour ?? 0, hm.minute ?? 0)).
        Her zaman Türkçe, kısa, net ve samimi cevap ver. Emin olmadığın bilgiyi uydurma, bilmiyorsan söyle.
        Plan ekleyemez ya da silemezsin; kullanıcı plan eklemek isterse Bugün ekranındaki + düğmesini kullanmasını söyle.
        Kullanıcının önümüzdeki 7 günlük planları:
        \(planText)\(next)
        """
    }

    @MainActor
    func send(_ raw: String) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        errorText = nil
        messages.append(ChatMessage(fromUser: true, text: text))
        save()
        busy = true
        defer { busy = false }

        let system = systemPrompt()
        let history = Array(messages.suffix(10))
        do {
            switch engine {
            case .apple:
                let answer = try await appleReply(system: system, history: history)
                messages.append(ChatMessage(fromUser: false, text: answer))
            case .gemini:
                let placeholder = ChatMessage(fromUser: false, text: "")
                messages.append(placeholder)
                let id = placeholder.id
                do {
                    let answer = try await GeminiEngine.stream(key: Self.geminiKey, model: Self.geminiModel,
                                                               system: system, history: history) { [weak self] text in
                        guard let self, let i = self.messages.firstIndex(where: { $0.id == id }) else { return }
                        self.messages[i].text = text
                    }
                    if let i = messages.firstIndex(where: { $0.id == id }) { messages[i].text = answer }
                } catch {
                    messages.removeAll { $0.id == id && $0.text.isEmpty }
                    throw error
                }
            case .none:
                errorText = "Asistan henüz kurulu değil. Daha fazla → Ayarlar → Asistan bölümüne bak."
                return
            }
            save()
        } catch {
            errorText = error.localizedDescription
            save()
        }
    }

    private func appleReply(system: String, history: [ChatMessage]) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            var prompt = ""
            let earlier = history.dropLast().suffix(6)
            if !earlier.isEmpty {
                prompt += "Önceki konuşma:\n"
                for m in earlier {
                    prompt += (m.fromUser ? "Kullanıcı: " : "Asistan: ") + m.text + "\n"
                }
                prompt += "\nYeni mesaj: "
            }
            prompt += history.last?.text ?? ""
            return try await AppleEngine.reply(system: system, prompt: prompt)
        }
        #endif
        throw GeminiEngine.Failure.message("Telefondaki model kullanılamıyor.")
    }
}

struct AssistantView: View {
    @Environment(AssistantStore.self) private var ai
    @State private var input = ""
    @State private var confirmClear = false
    @FocusState private var focused: Bool

    private let suggestions = [
        "Bugün neyim var?",
        "Bu hafta planlarım neler?",
        "Bana İngilizce bir cümle öğret",
        "Kısa bir motivasyon sözü söyle"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if ai.engine == .none {
                                setupCard
                            }
                            if ai.messages.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Ne sormak istersin?")
                                        .font(.title3.weight(.semibold))
                                    ForEach(suggestions, id: \.self) { s in
                                        Button {
                                            send(s)
                                        } label: {
                                            Text(s)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 9)
                                                .background(Color.loz.opacity(0.12), in: Capsule())
                                                .foregroundStyle(Color.loz)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, 8)
                            }
                            ForEach(ai.messages.filter { !$0.text.isEmpty }) { m in
                                bubble(m).id(m.id)
                            }
                            if ai.busy && (ai.messages.last?.fromUser == true || ai.messages.last?.text.isEmpty == true) {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Düşünüyor…").foregroundStyle(.secondary)
                                }
                                .id("busy")
                            }
                            if let e = ai.errorText {
                                Text(e)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .id("error")
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: ai.messages.count) { _, _ in
                        if let id = ai.messages.last(where: { !$0.text.isEmpty })?.id {
                            withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: ai.messages.last?.text.count ?? 0) { _, _ in
                        if let last = ai.messages.last, !last.text.isEmpty {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: ai.busy) { _, isBusy in
                        if isBusy { withAnimation { proxy.scrollTo("busy", anchor: .bottom) } }
                    }
                }
                Divider()
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Bir şey sor", text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    Button {
                        send(input)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canSend ? Color.loz : Color.gray.opacity(0.5))
                    }
                    .disabled(!canSend)
                    .accessibilityLabel("Gönder")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("Asistan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        confirmClear = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(ai.messages.isEmpty)
                    .accessibilityLabel("Yeni sohbet")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text(engineLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .confirmationDialog("Sohbet temizlensin mi?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Temizle", role: .destructive) { ai.clear() }
            }
        }
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !ai.busy && ai.engine != .none
    }

    private var engineLabel: String {
        switch ai.engine {
        case .apple: return "Telefondaki model"
        case .gemini: return "Gemini"
        case .none: return "Kurulu değil"
        }
    }

    private func send(_ text: String) {
        let t = text
        input = ""
        Task { await ai.send(t) }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Asistanı açmak için").font(.headline)
            Text("Telefonun Apple Intelligence destekliyorsa açman yeterli, internetsiz ve ücretsiz çalışır. Durum: \(AssistantStore.appleStatus)")
            Text("Desteklemiyorsa Google'dan ücretsiz bir Gemini anahtarı alıp Daha fazla → Ayarlar → Asistan bölümüne yapıştır.")
        }
        .font(.callout)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.loz.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.fromUser { Spacer(minLength: 40) }
            Text(LocalizedStringKey(m.text))
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(m.fromUser ? Color.loz : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(m.fromUser ? Color.white : Color.primary)
            if !m.fromUser { Spacer(minLength: 40) }
        }
    }
}

struct AssistantSettingsSection: View {
    @AppStorage("geminiKey") private var key = ""
    @AppStorage("geminiModel") private var model = GeminiEngine.defaultModel

    var body: some View {
        Section {
            HStack {
                Text("Telefondaki model")
                Spacer()
                Text(AssistantStore.appleAvailable ? "Hazır" : "Yok")
                    .foregroundStyle(AssistantStore.appleAvailable ? Color.green : Color.secondary)
            }
            if !AssistantStore.appleAvailable {
                Text(AssistantStore.appleStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            SecureField("Gemini API anahtarı", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Model (boş bırakırsan en hızlısı)", text: $model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.footnote)
            if let link = URL(string: "https://aistudio.google.com/apikey") {
                Link("Ücretsiz Gemini anahtarı al", destination: link)
            }
        } header: {
            Text("Asistan")
        } footer: {
            Text("Telefondaki model varsa o kullanılır: ücretsiz, internetsiz ve konuşmalar telefondan çıkmaz. Yoksa Gemini kullanılır. Gemini'nin ücretsiz sürümünde günlük bir sınır vardır ve Google gönderilen metinleri ürünlerini geliştirmek için kullanabilir, özel bilgi yazma.")
        }
    }
}
