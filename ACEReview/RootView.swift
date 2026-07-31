import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if !session.isAuthenticated {
                LoginView()
            } else if session.mustChangePassword {
                ChangePasswordView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: session.mustChangePassword)
    }
}

private struct MainTabView: View {
    @StateObject private var taskStore = TaskStore()
    @EnvironmentObject private var uploads: UploadManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                NewReviewView {
                    selectedTab = 1
                    Task { await taskStore.load() }
                }
            }
            .tabItem { Label("复盘", systemImage: "play.fill") }
            .tag(0)

            NavigationStack {
                TaskListView(taskStore: taskStore)
            }
            .tabItem { Label("任务库", systemImage: "folder.fill") }
            .tag(1)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("我的", systemImage: "person.fill") }
            .tag(2)
        }
        .tint(ACETheme.green)
        .toolbarBackground(ACETheme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .task { await taskStore.load() }
        .onChange(of: uploads.completionCounter) { _, _ in
            Task { await taskStore.load() }
        }
    }
}
