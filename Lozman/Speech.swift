import Foundation
import Speech
import AVFoundation
import Observation

/// Listens to the microphone and turns English speech into text.
@Observable
final class SpeechListener {
    var text = ""
    var listening = false
    var problem: String?
    @ObservationIgnored var onFinish: ((String) -> Void)?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var silence: Timer?
    @ObservationIgnored private var tapInstalled = false
    let locale: String

    init(locale: String = "en-US") { self.locale = locale }

    static func permissions() async -> Bool {
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    /// Starts listening; if already listening, stops.
    @MainActor
    func toggle() async {
        if listening { stop(); return }
        problem = nil
        guard await Self.permissions() else {
            problem = "Mikrofon ve konuşma tanıma izni gerekli: Ayarlar → Lozman."
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.isAvailable else {
            problem = "Konuşma tanıma şu an kullanılamıyor. İnternet bağlantını kontrol et."
            return
        }
        Sfx.stopSpeaking()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            problem = "Mikrofon açılamadı."
            return
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            problem = "Mikrofon bulunamadı."
            cleanup()
            return
        }
        if tapInstalled { input.removeTap(onBus: 0) }
        Self.installTap(on: input, format: format, request: req)
        tapInstalled = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            problem = "Mikrofon başlatılamadı."
            cleanup()
            return
        }
        text = ""
        listening = true
        task = startTask(recognizer: recognizer, request: req)
        armSilence(after: 7)
    }

    // Kept outside the main actor: these closures run on audio/background threads.
    private static func installTap(on input: AVAudioInputNode, format: AVAudioFormat, request: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    private func startTask(recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            let said = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = result == nil && error != nil
            DispatchQueue.main.async {
                guard let self, self.listening else { return }
                if let said {
                    self.text = said
                    self.armSilence(after: 1.6)
                }
                if isFinal || failed { self.finish() }
            }
        }
    }

    private func armSilence(after seconds: TimeInterval) {
        silence?.invalidate()
        silence = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.stop()
        }
    }

    /// Stops recording and waits a moment for the last words.
    func stop() {
        guard listening else { return }
        silence?.invalidate()
        request?.endAudio()
        if engine.isRunning { engine.stop() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in self?.finish() }
    }

    func cancel() {
        onFinish = nil
        if listening {
            listening = false
            cleanup()
        }
    }

    private func finish() {
        guard listening else { return }
        listening = false
        cleanup()
        onFinish?(text)
    }

    private func cleanup() {
        silence?.invalidate()
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Matching

    static func normalize(_ s: String) -> String {
        var t = s.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "’", with: "'")
        t = String(t.map { $0.isLetter || $0.isNumber || $0 == " " || $0 == "'" ? $0 : " " })
        // Treat British and American spellings the same.
        for (a, b) in [("our", "or"), ("tre", "ter"), ("is", "iz"), ("ll", "l"), ("ae", "e")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t.split(separator: " ").joined(separator: " ")
    }

    /// True if `target` was said somewhere in `text`.
    static func heard(_ target: String, in text: String) -> Bool {
        let t = normalize(target), h = normalize(text)
        guard !t.isEmpty, !h.isEmpty else { return false }
        if (" " + h + " ").contains(" " + t) { return true }
        let tw = t.split(separator: " ").map(String.init)
        let hw = h.split(separator: " ").map(String.init)
        func close(_ w: String) -> Bool {
            hw.contains { $0 == w || ($0.hasPrefix(w) && $0.count <= w.count + 3) || (w.count > 4 && $0.hasPrefix(String(w.dropLast()))) }
        }
        if tw.count == 1 { return close(tw[0]) }
        let important = tw.filter { $0.count > 2 }
        return (important.isEmpty ? tw : important).allSatisfy(close)
    }

    /// Share of the target's words that were said.
    static func overlap(_ target: String, _ text: String) -> Double {
        let tw = normalize(target).split(separator: " ").map(String.init)
        let hw = Set(normalize(text).split(separator: " ").map(String.init))
        guard !tw.isEmpty else { return 0 }
        return Double(tw.filter { hw.contains($0) }.count) / Double(tw.count)
    }
}
