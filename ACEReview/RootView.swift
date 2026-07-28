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

    var body: some View {
        TabView {
            NavigationStack {
                NewReviewView(taskStore: taskStore)
            }
            .tabItem { Label("新建复盘", systemImage: "plus.circle.fill") }

            NavigationStack {
                TaskListView(taskStore: taskStore)
            }
            .tabItem { Label("我的任务", systemImage: "rectangle.stack.fill") }

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
        }
        .tint(ACETheme.green)
        .task { await taskStore.load() }
    }
}

