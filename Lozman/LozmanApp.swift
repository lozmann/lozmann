import SwiftUI

@main
struct LozmanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = PlanStore.shared
    @State private var bjk = BJKStore.shared
    @State private var profile = ProfileStore.shared
    @State private var notes = NotesStore.shared
    @State private var assistant = AssistantStore.shared
    @State private var wishes = WishStore.shared
    @State private var news = NewsStore.shared
    @State private var dayKey = Day.today
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(dayKey)
                .environment(store)
                .environment(bjk)
                .environment(profile)
                .environment(notes)
                .environment(assistant)
                .environment(wishes)
                .environment(news)
                .tint(.loz)
                .onAppear {
                    Notifier.requestAuthorization()
                    Notifier.reschedule(store.plans)
                }
                .task { await bjk.refresh() }
                .onChange(of: phase) { _, newPhase in
                    if newPhase == .active {
                        dayKey = Day.today
                        Notifier.reschedule(store.plans)
                        Task { await bjk.refresh() }
                    }
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Bugün", systemImage: "sun.max.fill") }
            CalendarScreen()
                .tabItem { Label("Takvim", systemImage: "calendar") }
            AssistantView()
                .tabItem { Label("Asistan", systemImage: "sparkles") }
            NotesView()
                .tabItem { Label("Notlar", systemImage: "note.text") }
            MoreView()
                .tabItem { Label("Daha fazla", systemImage: "square.grid.2x2.fill") }
        }
    }
}

struct MoreView: View {
    @Environment(BJKStore.self) private var bjk

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PlansView()
                    } label: {
                        Label("Tüm planlar", systemImage: "list.bullet")
                    }
                    NavigationLink {
                        BJKView()
                    } label: {
                        HStack {
                            Label("Beşiktaş", systemImage: "soccerball")
                            Spacer()
                            if let m = bjk.nextMatch {
                                Text(Day.inDays(m.date))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink {
                        WishlistView()
                    } label: {
                        Label("Satın alacaklarım", systemImage: "cart.fill")
                    }
                    NavigationLink {
                        NewsView()
                    } label: {
                        Label("Gündem", systemImage: "newspaper.fill")
                    }
                }
                Section("Oyunlar") {
                    NavigationLink {
                        WordGameView()
                    } label: {
                        Label("İngilizce kelime oyunu", systemImage: "character.book.closed.fill")
                    }
                    NavigationLink {
                        SlitherView()
                    } label: {
                        Label("Yılan.io", systemImage: "scribble.variable")
                    }
                }
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Ayarlar", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("Daha fazla")
        }
    }
}
