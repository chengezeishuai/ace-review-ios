import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case notFound
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应异常"
        case .notFound:
            return "任务不存在"
        case .server(let message):
            return message
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private let decoder = JSONDecoder()

    private init() {}

    func url(for path: String) -> URL {
        let normalized = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: normalized, relativeTo: AppSettings.shared.baseURL)!.absoluteURL
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        if let configurationError = AppSettings.shared.configurationError {
            throw APIClientError.server(configurationError)
        }
        var request = URLRequest(url: url(for: path))
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppSettings.shared.clientID, forHTTPHeaderField: "clientid")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token = KeychainStore.get("accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 {
                throw APIClientError.notFound
            }
            let detail = serverMessage(data, fallback: "请求失败（\(http.statusCode)）")
            throw APIClientError.server(detail)
        }
        if T.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! T
        }
        let envelope = try decoder.decode(RuoYiEnvelope<T>.self, from: data)
        guard envelope.code == 200 else {
            throw APIClientError.server(envelope.message ?? "请求未完成")
        }
        if let value = envelope.data {
            return value
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        throw APIClientError.invalidResponse
    }

    private func serverMessage(_ data: Data, fallback: String) -> String {
        (try? decoder.decode(RuoYiMessage.self, from: data).message) ?? fallback
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        try await request(
            "api/app/login",
            method: "POST",
            body: ["username": username, "password": password],
            authenticated: false
        )
    }

    func changePassword(current: String, new: String) async throws -> PasswordChangeResponse {
        try await request(
            "api/app/account/password",
            method: "POST",
            body: ["current_password": current, "new_password": new]
        )
    }

    func tasks() async throws -> [TaskItem] {
        try await request("api/app/tasks")
    }

    func memberships() async throws -> MembershipEnvelope {
        try await request("api/app/account/memberships")
    }

    func entitlements() async throws -> EntitlementEnvelope {
        try await request("api/app/account/entitlements")
    }

    func task(id: String) async throws -> TaskItem {
        try await request("api/app/tasks/\(id)")
    }

    func reportSummary(taskID: String) async throws -> ReportSummary {
        try await request("api/app/tasks/\(taskID)/report/summary")
    }

    func comments(taskID: String) async throws -> CoachCommentEnvelope {
        try await request("api/app/tasks/\(taskID)/comments")
    }

    func addComment(taskID: String, content: String) async throws {
        let _: EmptyResponse = try await request("api/app/tasks/\(taskID)/comments", method: "POST", body: ["content": content])
    }

    func trainingPlans() async throws -> TrainingPlanEnvelope {
        try await request("api/app/training-plans")
    }

    func progress() async throws -> ProgressSummary {
        try await request("api/app/account/progress")
    }

    func commerceCatalog() async throws -> [CommerceProduct] {
        try await request("api/app/commerce/catalog")
    }

    func purchase(productCode: String) async throws -> CommerceOrder {
        try await request("api/app/commerce/orders", method: "POST", body: [
            "productCode": productCode,
            "idempotencyKey": UUID().uuidString.replacingOccurrences(of: "-", with: "")
        ])
    }

    func commerceOrders() async throws -> [CommerceOrderHistoryItem] {
        try await request("api/app/commerce/orders")
    }

    func retryTask(id: String) async throws -> TaskItem {
        try await request(
            "api/app/tasks/\(id)/retry",
            method: "POST"
        )
    }

    func reanalyzeTask(id: String, focus: String, label: String) async throws -> TaskItem {
        try await request(
            "api/app/tasks/\(id)/reanalyze",
            method: "POST",
            body: ["focus": focus, "label": label]
        )
    }

    func deleteTask(id: String) async throws {
        let _: EmptyResponse = try await request(
            "api/app/tasks/\(id)",
            method: "DELETE"
        )
    }

    func renameTask(id: String, title: String) async throws -> TaskItem {
        try await request(
            "api/app/tasks/\(id)",
            method: "PATCH",
            body: ["title": title]
        )
    }

    func createStreamingUpload(
        filename: String,
        mimeType: String,
        title: String,
        player: String,
        notes: String,
        capturedAt: String?,
        captureLocation: String?
    ) async throws -> StreamingUploadResponse {
        try await request(
            "api/app/uploads",
            method: "POST",
            body: [
                "filename": filename,
                "mimeType": mimeType,
                "title": title,
                "player": player,
                "notes": notes,
                "capturedAt": capturedAt ?? "",
                "captureLocation": captureLocation ?? ""
            ]
        )
    }

    func createEvidence(
        title: String, player: String, notes: String,
        durationSeconds: TimeInterval, frameCount: Int
    ) async throws -> EvidenceCreateResponse {
        try await request("api/app/evidence", method: "POST", body: [
            "title": title, "player": player, "notes": notes,
            "durationSeconds": durationSeconds, "frameCount": frameCount
        ])
    }

    func uploadEvidenceFrame(taskID: String, index: Int, data: Data) async throws {
        var request = URLRequest(url: url(for: "api/app/evidence/\(taskID)/frames/\(index)"))
        request.httpMethod = "PUT"
        request.timeoutInterval = 60
        request.httpBody = data
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(AppSettings.shared.clientID, forHTTPHeaderField: "clientid")
        if let token = KeychainStore.get("accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = serverMessage(responseData, fallback: "证据帧上传失败")
            throw APIClientError.server(detail)
        }
        let envelope = try decoder.decode(RuoYiEnvelope<EmptyResponse>.self, from: responseData)
        guard envelope.code == 200 else { throw APIClientError.server(envelope.message ?? "证据帧上传失败") }
    }

    func finalizeEvidence(taskID: String, durationSeconds: TimeInterval, frameCount: Int) async throws -> EmptyResponse {
        try await request("api/app/evidence/\(taskID)/finalize", method: "POST", body: [
            "durationSeconds": durationSeconds, "frameCount": frameCount
        ])
    }

    func download(path: String) async throws -> URL {
        var request = URLRequest(url: url(for: path))
        request.setValue(AppSettings.shared.clientID, forHTTPHeaderField: "clientid")
        if let token = KeychainStore.get("accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw APIClientError.invalidResponse
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".pdf")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }
}

private struct RuoYiEnvelope<Payload: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: Payload?

    enum CodingKeys: String, CodingKey {
        case code, data
        case message = "msg"
    }
}

private struct RuoYiMessage: Decodable {
    let message: String?
    enum CodingKeys: String, CodingKey { case message = "msg" }
}
