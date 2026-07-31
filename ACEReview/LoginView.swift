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
                    Spacer(minLength: 72)
                    brand
                    VStack(alignment: .leading, spacing: 18) {
                        Text("欢迎回来")
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .foregroundStyle(ACETheme.ink)
                        Text("登录后提交训练录像，并随时查看分析进度。")
                            .foregroundStyle(ACETheme.muted)

                        TextField("账号", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .padding(16)
                            .background(Color.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        SecureField("密码", text: $password)
                            .textContentType(.password)
                            .padding(16)
                            .background(Color.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

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
                Text("TENNIS REVIEW")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.2)
                    .foregroundStyle(ACETheme.green)
            }
        }
    }
}
