import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""

    var body: some View {
        ZStack {
            ACEBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ACEIconBadge(systemImage: "key.fill", size: 52)
                    Text("设置安全密码")
                        .font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(ACETheme.ink)
                    Text("至少 8 位，建议组合字母、数字和符号，并避免与其他服务重复。")
                        .font(.subheadline).foregroundStyle(ACETheme.muted)
                    VStack(spacing: 0) {
                        passwordField("当前密码", text: $currentPassword, contentType: .password)
                        Divider().overlay(ACETheme.cardLine).padding(.leading, 16)
                        passwordField("新密码", text: $newPassword, contentType: .newPassword)
                        Divider().overlay(ACETheme.cardLine).padding(.leading, 16)
                        passwordField("再次输入新密码", text: $confirmation, contentType: .newPassword)
                    }
                    .background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

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
                    if !confirmation.isEmpty && newPassword != confirmation {
                        Label("两次输入的新密码不一致", systemImage: "exclamationmark.circle.fill")
                            .font(.caption).foregroundStyle(ACETheme.danger)
                    }
                }
                .padding(20).padding(.bottom, 30)
            }
        }
        .navigationTitle("修改密码")
        .navigationBarTitleDisplayMode(.inline)
        .aceKeyboardSupport()
    }

    private func passwordField(_ title: String, text: Binding<String>, contentType: UITextContentType) -> some View {
        SecureField(title, text: text)
            .textContentType(contentType)
            .foregroundStyle(ACETheme.cardInk)
            .padding(.horizontal, 16).frame(height: 58)
    }
}
