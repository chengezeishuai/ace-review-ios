import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var username: String
    @Published var mustChangePassword: Bool
    @Published var isWorking = false
    @Published var errorMessage = ""

    init() {
        let token = KeychainStore.get("accessToken")
        username = UserDefaults.standard.string(forKey: "ace.username") ?? ""
        isAuthenticated = token != nil
        mustChangePassword = UserDefaults.standard.bool(forKey: "ace.mustChangePassword")
    }

    func login(username: String, password: String) async {
        isWorking = true
        errorMessage = ""
        defer { isWorking = false }
        do {
            let response = try await APIClient.shared.login(
                username: username,
                password: password
            )
            KeychainStore.set(response.accessToken, for: "accessToken")
            self.username = response.username
            mustChangePassword = response.mustChangePassword
            UserDefaults.standard.set(response.username, forKey: "ace.username")
            UserDefaults.standard.set(
                response.mustChangePassword,
                forKey: "ace.mustChangePassword"
            )
            isAuthenticated = true
        } catch {
            errorMessage = localizedError(error)
        }
    }

    func changePassword(current: String, new: String) async {
        isWorking = true
        errorMessage = ""
        defer { isWorking = false }
        do {
            let response = try await APIClient.shared.changePassword(
                current: current,
                new: new
            )
            KeychainStore.set(response.accessToken, for: "accessToken")
            mustChangePassword = false
            UserDefaults.standard.set(false, forKey: "ace.mustChangePassword")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        KeychainStore.remove("accessToken")
        UserDefaults.standard.removeObject(forKey: "ace.username")
        UserDefaults.standard.removeObject(forKey: "ace.mustChangePassword")
        username = ""
        mustChangePassword = false
        isAuthenticated = false
    }

    private func localizedError(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("password input error")
            || message.localizedCaseInsensitiveContains("password") {
            return "账号或密码不正确，请重新输入"
        }
        if message.localizedCaseInsensitiveContains("mobile client") {
            return "移动端服务暂未配置完成，请联系平台管理员"
        }
        return message
    }
}
