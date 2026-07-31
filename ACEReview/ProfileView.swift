import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var memberships: [MembershipItem] = []
    @State private var loadError = ""
    @State private var showLogout = false

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    brandHeader
                    accountCard
                    if !loadError.isEmpty {
                        Label(loadError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ACETheme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    if !memberships.isEmpty { roleCard }
                    settingsCard
                    Button(role: .destructive) { showLogout = true } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(17)
                    }
                    .background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 30)
            }
        }
        .task { await loadProfile() }
        .alert("退出当前账号？", isPresented: $showLogout) {
            Button("退出", role: .destructive) { session.logout() }
            Button("取消", role: .cancel) {}
        }
    }

    private var brandHeader: some View {
        HStack { Spacer(); HStack(spacing: 8) { ACEBrandMark(size: 29); Text("ACE Review").font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(ACETheme.green) }; Spacer(); Image(systemName: "gearshape").foregroundStyle(ACETheme.ink) }
            .frame(height: 38)
    }

    private var accountCard: some View {
        HStack(spacing: 15) {
            Text(initials).font(.system(size: 28, weight: .medium, design: .rounded)).foregroundStyle(.white).frame(width: 72, height: 72).background(ACETheme.green).clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) { Text(session.username.isEmpty ? "ACE 用户" : session.username).font(.title3.bold()).foregroundStyle(ACETheme.ink); Text("网球训练复盘").font(.subheadline).foregroundStyle(ACETheme.muted); Label("个人资料", systemImage: "person.crop.circle").font(.caption).foregroundStyle(ACETheme.muted) }
            Spacer()
        }
        .padding(17).background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay { RoundedRectangle(cornerRadius: 16).stroke(ACETheme.line, lineWidth: 1) }
    }

    private var roleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("身份与组织", systemImage: "person.2").font(.headline).foregroundStyle(ACETheme.ink)
            ForEach(memberships) { item in
                HStack { VStack(alignment: .leading, spacing: 3) { Text(item.name).font(.subheadline.bold()); Text(roleName(item.roleCode)).font(.caption).foregroundStyle(ACETheme.muted) }; Spacer(); Image(systemName: "checkmark.circle.fill").foregroundStyle(ACETheme.green) }
            }
        }
        .padding(17).background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay { RoundedRectangle(cornerRadius: 16).stroke(ACETheme.line, lineWidth: 1) }
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingRow("账号安全", "lock")
            Divider().padding(.leading, 42)
            settingRow("隐私与数据", "hand.raised")
            Divider().padding(.leading, 42)
            settingRow("帮助与支持", "questionmark.circle")
        }
        .padding(.vertical, 4).background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay { RoundedRectangle(cornerRadius: 16).stroke(ACETheme.line, lineWidth: 1) }
    }

    private func settingRow(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 13) { Image(systemName: icon).foregroundStyle(ACETheme.green).frame(width: 20); Text(title).font(.subheadline).foregroundStyle(ACETheme.ink); Spacer() }.padding(.horizontal, 17).frame(height: 54)
    }

    private var initials: String { String((session.username.isEmpty ? "A" : session.username).prefix(2)).uppercased() }
    private func roleName(_ code: String) -> String { switch code { case "coach": "教练"; case "athlete": "运动员"; default: "成员" } }
    private func loadProfile() async { do { memberships = try await APIClient.shared.memberships().memberships } catch { loadError = error.localizedDescription } }
}
