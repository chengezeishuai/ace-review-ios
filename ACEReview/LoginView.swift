import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            ACEBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Spacer(minLength: 56)
                    brand
                    VStack(alignment: .leading, spacing: 18) {
                        Text("欢迎回来")
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .foregroundStyle(ACETheme.ink)
                        Text("登录后提交训练录像，并随时查看分析进度。")
                            .foregroundStyle(ACETheme.muted)

                        Text("账号登录")
                            .font(.headline)
                            .foregroundStyle(ACETheme.ink)
                        loginField(title: "账号", systemImage: "person") {
                            TextField("请输入账号", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                        }

                        loginField(title: "密码", systemImage: "lock") {
                            SecureField("请输入密码", text: $password)
                                .textContentType(.password)
                        }

                        if !session.errorMessage.isEmpty {
                            Text(session.errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Button {
                            Task {
                                await session.login(
                                    username: username,
                                    password: password
                                )
                            }
                        } label: {
                            PrimaryActionLabel(
                                title: session.isWorking ? "正在登录" : "登录",
                                systemImage: "arrow.right",
                                isWorking: session.isWorking
                            )
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(
                            username.trimmingCharacters(in: .whitespaces).isEmpty
                                || password.isEmpty
                                || session.isWorking
                        )
                    }
                    .aceCard()
                    Text("使用 ACE 平台开通的账号登录，训练资料仅用于本次复盘服务。")
                        .font(.caption)
                        .foregroundStyle(ACETheme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 22)
            }
        }
    }

    private var brand: some View {
        HStack(spacing: 14) {
            ACEBrandMark(size: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text("ACE 复盘")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(ACETheme.ink)
                Text("网球训练复盘")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.2)
                    .foregroundStyle(ACETheme.green)
            }
        }
    }

    private func loginField<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundStyle(ACETheme.muted)
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .foregroundStyle(ACETheme.green)
                    .frame(width: 18)
                content()
                    .foregroundStyle(ACETheme.ink)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(ACETheme.cream.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ACETheme.line, lineWidth: 1) }
        }
    }
}
