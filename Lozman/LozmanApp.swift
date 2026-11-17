import SwiftUI

@main
struct LozmanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = PlanStore.shared
    @State private var bjk = BJKStore.shared
    @State private var dayKey = Day.today
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(dayKey)
                .environment(store)
                .environment(bjk)
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
            PlansView()
                .tabItem { Label("Planlar", systemImage: "list.bullet") }
            BJKView()
                .tabItem { Label("Beşiktaş", systemImage: "soccerball") }
            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }
        }
    }
}
