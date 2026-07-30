import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var showLogout = false
    @State private var memberships: [MembershipItem] = []
    @State private var entitlements: [EntitlementItem] = []
    @State private var trainingPlans: [TrainingPlan] = []
    @State private var progress: ProgressSummary?
    @State private var loadError = ""

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
                            Text(memberships.isEmpty ? "个人训练空间" : "多身份训练空间")
                                .font(.subheadline)
                                .foregroundStyle(ACETheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .aceCard()

                    if let progress {
                        HStack(spacing: 0) {
                            progressMetric("完成复盘", value: progress.totalCompleted)
                            Divider().frame(height: 36)
                            progressMetric("云端", value: progress.cloudCompleted)
                            Divider().frame(height: 36)
                            progressMetric("本地", value: progress.localCompleted)
                        }
                        .aceCard()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("分析额度")
                            .font(.headline)
                        if entitlements.isEmpty {
                            Text("当前没有可用额度，请联系平台管理员开通套餐。")
                                .font(.subheadline)
                                .foregroundStyle(ACETheme.muted)
                        } else {
                            ForEach(entitlements) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(planName(item.planCode)).font(.subheadline.bold())
                                        if let owner = item.ownerName, owner != "个人" {
                                            Text(owner).font(.caption).foregroundStyle(ACETheme.muted)
                                        }
                                    }
                                    Spacer()
                                    Text("云端 \(item.cloudRemaining) · 本地 \(item.localRemaining)")
                                        .font(.caption.bold())
                                        .foregroundStyle(ACETheme.green)
                                }
                                if item.id != entitlements.last?.id { Divider() }
                            }
                        }
                    }
                    .aceCard()

                    if !memberships.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("我的组织与身份").font(.headline)
                            ForEach(memberships) { item in
                                HStack {
                                    Image(systemName: "person.2.fill").foregroundStyle(ACETheme.green)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name).font(.subheadline.bold())
                                        Text(roleName(item.roleCode)).font(.caption).foregroundStyle(ACETheme.muted)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .aceCard()
                    }

                    if !trainingPlans.isEmpty {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("训练计划").font(.headline)
                            ForEach(trainingPlans) { plan in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(plan.title).font(.subheadline.bold())
                                    if !plan.goal.isEmpty {
                                        Text(plan.goal).font(.caption).foregroundStyle(ACETheme.muted)
                                    }
                                    ForEach(plan.items.prefix(3), id: \.self) { item in
                                        Label(item, systemImage: "checkmark.circle")
                                            .font(.caption)
                                            .foregroundStyle(ACETheme.green)
                                    }
                                }
                                if plan.id != trainingPlans.last?.id { Divider() }
                            }
                        }
                        .aceCard()
                    }

                    if !loadError.isEmpty {
                        Text(loadError).font(.caption).foregroundStyle(.red)
                    }

                    VStack(spacing: 0) {
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
        .task { await loadAccount() }
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

    private func loadAccount() async {
        do {
            async let membershipRequest = APIClient.shared.memberships()
            async let entitlementRequest = APIClient.shared.entitlements()
            async let plansRequest = APIClient.shared.trainingPlans()
            async let progressRequest = APIClient.shared.progress()
            let (membershipResponse, entitlementResponse, plansResponse, progressResponse) = try await (membershipRequest, entitlementRequest, plansRequest, progressRequest)
            memberships = membershipResponse.memberships
            entitlements = entitlementResponse.entitlements
            trainingPlans = plansResponse.plans
            progress = progressResponse
        } catch {
            loadError = "账户权益暂时无法加载"
        }
    }

    private func planName(_ code: String) -> String {
        ["trial": "体验包", "personal": "ACE 个人", "plus": "ACE Plus", "coach": "教练版", "club": "俱乐部版"][code] ?? code
    }

    private func roleName(_ code: String) -> String {
        ["athlete": "学员", "coach": "教练", "parent": "家长", "agent": "代理商", "club_admin": "俱乐部管理员", "region_admin": "区域管理员", "team_admin": "校队管理员", "club_operator": "俱乐部运营"][code] ?? code
    }

    private func progressMetric(_ label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.title3.bold()).foregroundStyle(ACETheme.green)
            Text(label).font(.caption).foregroundStyle(ACETheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
