import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var settings = AppSettings.shared
    @State private var showServer = false
    @State private var showLogout = false

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ACCOUNT")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2.3)
                            .foregroundStyle(ACETheme.green)
                        Text("我的")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(ACETheme.ink)
                    }
                    .padding(.top, 18)

                    HStack(spacing: 16) {
                        Circle()
                            .fill(ACETheme.ink)
                            .frame(width: 62, height: 62)
                            .overlay {
                                Text(initials)
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.username)
                                .font(.title3.bold())
                                .foregroundStyle(ACETheme.ink)
                            Text("个人训练空间")
                                .font(.subheadline)
                                .foregroundStyle(ACETheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .aceCard()

                    VStack(spacing: 0) {
                        Button {
                            showServer.toggle()
                        } label: {
                            settingsRow("服务器设置", icon: "network")
                        }
                        if showServer {
                            TextField("服务器地址", text: $settings.serverURLString)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.top, 12)
                        }
                        Divider().padding(.vertical, 14)
                        Button(role: .destructive) {
                            showLogout = true
                        } label: {
                            settingsRow("退出登录", icon: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                        }
                    }
                    .aceCard()
                }
                .padding(18)
            }
        }
        .navigationBarHidden(true)
        .confirmationDialog(
            "确认退出当前账号？",
            isPresented: $showLogout,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) { session.logout() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("系统后台上传任务不会删除，再次登录后可继续。")
        }
    }

    private var initials: String {
        String(session.username.prefix(2)).uppercased()
    }

    private func settingsRow(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 28)
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(ACETheme.muted)
        }
        .foregroundStyle(ACETheme.ink)
        .contentShape(Rectangle())
    }
}

