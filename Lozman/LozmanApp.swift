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
    @State private var habits = HabitStore.shared
    @State private var focus = FocusStore.shared
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
                .environment(habits)
                .environment(focus)
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
                        Backup.autoBackupIfNeeded()
                        Task { await bjk.refresh() }
                    } else if newPhase == .background {
                        Backup.autoBackupIfNeeded()
                        Background.schedule()
                    }
                }
        }
    }
}

struct RootView: View {
    @State private var router = AppRouter.shared

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
        .sheet(item: $router.sheet) { s in
            switch s {
            case .morning: MorningPlanView()
            case .review: EveningReviewView()
            }
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
                        HabitsView()
                    } label: {
                        Label("Alışkanlıklar", systemImage: "flame.fill")
                    }
                    NavigationLink {
                        FocusView()
                    } label: {
                        Label("Odak zamanlayıcı", systemImage: "timer")
                    }
                    NavigationLink {
                        StatsView()
                    } label: {
                        Label("İstatistikler", systemImage: "chart.bar.fill")
                    }
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
                    NavigationLink {
                        BlockBlastView()
                    } label: {
                        Label("Blok Patlat", systemImage: "square.grid.3x3.fill")
                    }
                    NavigationLink {
                        Game2048View()
                    } label: {
                        Label("2048", systemImage: "number.square.fill")
                    }
                    NavigationLink {
                        StackGameView()
                    } label: {
                        Label("Kule", systemImage: "square.stack.3d.up.fill")
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
