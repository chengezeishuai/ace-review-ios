import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var memberships: [MembershipItem] = []
    @State private var loadError = ""
    @State private var showLogout = false

    var body: some View {
        ZStack {
            ACEBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    accountHero
                    if !loadError.isEmpty { errorBanner }
                    if !memberships.isEmpty { organizationStrip }
                    sectionLabel("训练与个性化")
                    trainingGroup
                    sectionLabel("账户与服务")
                    accountGroup
                    logoutButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
        }
        .task { await loadProfile() }
        .alert("退出当前账号？", isPresented: $showLogout) {
            Button("退出", role: .destructive) { session.logout() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("本机登录凭证将被清除，云端训练与报告不会被删除。")
        }
    }

    private var header: some View {
        ACEPageHeader(eyebrow: "ACCOUNT", title: "我的", subtitle: "训练资料、隐私与偏好，一处管理。") {
            NavigationLink { GeneralSettingsView() } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ACETheme.ink)
                    .frame(width: 44, height: 44)
                    .background(ACETheme.paper, in: Circle())
                    .overlay { Circle().stroke(ACETheme.cardLine, lineWidth: 1) }
            }
        }
    }

    private var accountHero: some View {
        NavigationLink { ProfileDetailsView(username: session.username) } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(.white.opacity(0.16))
                    Text(initials)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(ACETheme.onPrimary)
                }
                .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.username.isEmpty ? "ACE 用户" : session.username)
                        .font(.title3.bold())
                    Text("网球训练复盘账号")
                        .font(.subheadline)
                        .opacity(0.76)
                    Label("查看个人资料", systemImage: "person.text.rectangle")
                        .font(.caption.weight(.semibold))
                        .opacity(0.86)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).opacity(0.74)
            }
            .foregroundStyle(ACETheme.onPrimary)
            .padding(19)
            .background(ACETheme.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: ACETheme.green.opacity(0.18), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var organizationStrip: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("当前身份", systemImage: "person.2.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(ACETheme.cardMuted)
                Spacer()
                Text("共 (memberships.count) 个组织").font(.caption2).foregroundStyle(ACETheme.cardMuted)
            }
            ForEach(memberships) { item in
                HStack(spacing: 10) {
                    Circle().fill(ACETheme.green).frame(width: 8, height: 8)
                    Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(ACETheme.cardInk)
                    Spacer()
                    Text(roleName(item.roleCode)).font(.caption).foregroundStyle(ACETheme.cardMuted)
                }
            }
        }
        .aceCard()
    }

    private var trainingGroup: some View {
        ACEGroupCard {
            VStack(spacing: 0) {
                NavigationLink { PerformanceCenterView() } label: {
                    ACESettingsRow(icon: "chart.xyaxis.line", title: "训练表现", subtitle: "评分趋势与已计入报告")
                }.buttonStyle(.plain)
                cardDivider
                NavigationLink { ThemePaletteView() } label: {
                    ACESettingsRow(icon: "paintpalette.fill", title: "主题配色", subtitle: "预设与自由调色盘")
                }.buttonStyle(.plain)
            }
        }
    }

    private var accountGroup: some View {
        ACEGroupCard {
            VStack(spacing: 0) {
                NavigationLink { AccountSecurityView() } label: {
                    ACESettingsRow(icon: "lock.shield.fill", title: "账号安全", subtitle: "密码、凭证与账号注销")
                }.buttonStyle(.plain)
                cardDivider
                NavigationLink { PrivacyCenterView() } label: {
                    ACESettingsRow(icon: "hand.raised.fill", title: "隐私与数据", subtitle: "权限、数据使用与正式协议")
                }.buttonStyle(.plain)
                cardDivider
                NavigationLink { GeneralSettingsView() } label: {
                    ACESettingsRow(icon: "gearshape.fill", title: "设置", subtitle: "上传、报告与外观偏好")
                }.buttonStyle(.plain)
                cardDivider
                NavigationLink { SupportView() } label: {
                    ACESettingsRow(icon: "questionmark.bubble.fill", title: "帮助与支持", subtitle: "常见问题与问题诊断")
                }.buttonStyle(.plain)
            }
        }
    }

    private var logoutButton: some View {
        Button { showLogout = true } label: {
            Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ACETheme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ACETheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var errorBanner: some View {
        Label(loadError, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote).foregroundStyle(ACETheme.danger)
            .padding(13).frame(maxWidth: .infinity, alignment: .leading)
            .background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var cardDivider: some View { Divider().overlay(ACETheme.cardLine).padding(.leading, 66) }
    private func sectionLabel(_ value: String) -> some View { Text(value).font(.caption.weight(.bold)).foregroundStyle(ACETheme.muted).tracking(0.8).padding(.leading, 4) }
    private var initials: String { String((session.username.isEmpty ? "A" : session.username).prefix(2)).uppercased() }
    private func roleName(_ code: String) -> String { switch code { case "coach": "教练"; case "athlete": "运动员"; default: "成员" } }
    private func loadProfile() async { do { memberships = try await APIClient.shared.memberships().memberships } catch { loadError = error.localizedDescription } }
}
