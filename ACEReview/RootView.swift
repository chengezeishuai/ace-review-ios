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
                }
            }
            .tabItem { Label("新建复盘", systemImage: "plus.circle.fill") }
            .tag(0)

            NavigationStack {
                TaskListView(taskStore: taskStore)
            }
            .tabItem { Label("我的任务", systemImage: "rectangle.stack.fill") }
            .tag(1)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
            .tag(2)
        }
        .tint(ACETheme.green)
        .task { await taskStore.load() }
        .onAppear {
            if uploads.hasActiveUpload {
                selectedTab = 1
            }
        }
        .onChange(of: uploads.snapshot.phase) { _, phase in
            guard phase == .completed else { return }
            selectedTab = 1
            uploads.acknowledgeCompletion()
            Task { await taskStore.load() }
        }
    }
}
