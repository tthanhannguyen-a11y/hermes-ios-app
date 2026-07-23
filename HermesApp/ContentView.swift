import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
                .tag(0)

            SessionListView()
                .tabItem {
                    Label("Sessions", systemImage: "list.clipboard")
                }
                .tag(1)

            JobListView()
                .tabItem {
                    Label("Jobs", systemImage: "clock")
                }
                .tag(2)

            StatusView()
                .tabItem {
                    Label("Status", systemImage: "gauge.with.dots.needle.33percent")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
    }
}
