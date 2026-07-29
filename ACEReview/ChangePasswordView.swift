import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ACETheme.cream.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("保护你的账号")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(ACETheme.ink)
                    Text("首次登录需要设置一个不少于8位的新密码。")
                        .foregroundStyle(ACETheme.muted)
                    Group {
                        SecureField("当前密码", text: $currentPassword)
                        SecureField("新密码", text: $newPassword)
                        SecureField("再次输入新密码", text: $confirmation)
                    }
                    .textContentType(.newPassword)
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    if !session.errorMessage.isEmpty {
                        Text(session.errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Button {
                        Task {
                            await session.changePassword(
                                current: currentPassword,
                                new: newPassword
                            )
                        }
                    } label: {
                        PrimaryActionLabel(
                            title: session.isWorking ? "正在保存" : "保存新密码",
                            systemImage: "checkmark",
                            isWorking: session.isWorking
                        )
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(
                        currentPassword.isEmpty
                            || newPassword.count < 8
                            || newPassword != confirmation
                            || session.isWorking
                    )
                    Spacer()
                }
                .aceCard()
                .padding(22)
            }
        }
    }
}
