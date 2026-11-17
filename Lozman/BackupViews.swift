import SwiftUI
import UniformTypeIdentifiers

struct BackupSection: View {
    @State private var pickingFolder = false
    @State private var pickingFile = false
    @State private var confirmRestore: URL?
    @State private var message: String?
    @State private var shareURL: URL?
    @State private var refresh = 0

    var body: some View {
        Section {
            HStack {
                Text("Yedek klasörü")
                Spacer()
                Text(Backup.folderName ?? "Seçilmedi")
                    .foregroundStyle(Backup.hasFolder ? Color.secondary : Color.red)
            }
            .id(refresh)
            Button(Backup.hasFolder ? "Klasörü değiştir" : "Yedek klasörü seç") { pickingFolder = true }
                .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
                    if case .success(let url) = result, Backup.setFolder(url) {
                        message = "Klasör seçildi. İlk yedek alınıyor…"
                        do {
                            let name = try Backup.backupNow()
                            message = "Yedek alındı: \(name)"
                        } catch {
                            message = error.localizedDescription
                        }
                    } else {
                        message = "Klasör seçilemedi."
                    }
                    refresh += 1
                }
            if Backup.hasFolder {
                Button("Şimdi yedekle") {
                    do {
                        let name = try Backup.backupNow()
                        message = "Yedek alındı: \(name)"
                        Sfx.play("correct")
                    } catch {
                        message = error.localizedDescription
                    }
                    refresh += 1
                }
                if let last = Backup.lastBackup {
                    LabeledContent("Son yedek", value: "\(Day.nice(Day.key(last))) \(WorkClock.format(WorkClock.minutes(last)))")
                        .id(refresh)
                }
            }
            if let shareURL {
                ShareLink(item: shareURL) {
                    Label("Yedeği dosya olarak gönder", systemImage: "square.and.arrow.up")
                }
            }
            Button("Yedekten geri yükle", role: .destructive) { pickingFile = true }
                .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.json]) { result in
                    if case .success(let url) = result { confirmRestore = url }
                }
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Yedekleme")
        } footer: {
            Text("Bir kez klasör seç (en iyisi iCloud Drive'da \"Lozman\" diye bir klasör). Lozman her gün kendiliğinden yedek alır, son 14 günü saklar. Uygulamayı silip yeniden kurman gerekirse \"Yedekten geri yükle\" ile her şey geri gelir.")
        }
        .confirmationDialog("Bu yedek yüklensin mi? Şu anki planların, notların, alışkanlıkların ve alışveriş listen yedektekilerle değiştirilecek.",
                            isPresented: Binding(get: { confirmRestore != nil }, set: { if !$0 { confirmRestore = nil } }),
                            titleVisibility: .visible) {
            Button("Geri yükle", role: .destructive) {
                guard let url = confirmRestore else { return }
                do {
                    let n = try Backup.restore(from: url)
                    message = "Geri yüklendi: \(n) kayıt."
                    Sfx.play("levelup")
                } catch {
                    message = "Bu dosya okunamadı. Lozman yedeği olduğundan emin ol."
                }
                confirmRestore = nil
            }
        }
        .onAppear {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Lozman-yedek-\(Day.today).json")
            if let data = try? Backup.encoded(), (try? data.write(to: url, options: .atomic)) != nil {
                shareURL = url
            }
        }
    }
}

struct SiriHelpSection: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("\"Hey Siri, Lozman'a ekle\" de, Siri ne ekleyeceğini sorar. Örn: \"yarın 3'te dişçi\".", systemImage: "mic.fill")
                Label("\"Hey Siri, Lozman bugün neyim var\" dersen bugünkü planlarını okur.", systemImage: "sun.max.fill")
                Label("Eylem düğmesi: Ayarlar → Eylem Düğmesi → Kestirme → Lozman → Plan ekle.", systemImage: "button.horizontal.top.press.fill")
                Label("Paylaş menüsü: Kestirmeler uygulamasında yeni kestirme oluştur, \"Paylaşım Sayfasında Göster\"i aç, eylem olarak \"Lozman'a ekle\"yi seç ve Plan alanına \"Kestirme Girdisi\"ni koy. Artık bir mesajı ya da metni Paylaş → bu kestirme ile Lozman'a atabilirsin.", systemImage: "square.and.arrow.up")
            }
            .font(.callout)
            .padding(.vertical, 4)
        } header: {
            Text("Siri ve kısayollar")
        } footer: {
            Text("Siri komutları güncellemeden sonra uygulama bir kez açılınca etkinleşir.")
        }
    }
}
