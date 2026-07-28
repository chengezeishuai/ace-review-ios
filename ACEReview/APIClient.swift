import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应异常"
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
        URL(string: path, relativeTo: AppSettings.shared.baseURL)!.absoluteURL
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
            let detail = (try? decoder.decode(APIErrorBody.self, from: data).detail)
                ?? "请求失败（\(http.statusCode)）"
            throw APIClientError.server(detail)
        }
        if T.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
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
            "api/change-password",
            method: "POST",
            body: ["current_password": current, "new_password": new]
        )
    }

    func tasks() async throws -> [TaskItem] {
        try await request("api/tasks")
    }

    func retryTask(id: String) async throws -> TaskEnvelope {
        try await request(
            "api/tasks/\(id)/retry",
            method: "POST"
        )
    }

    func createStreamingUpload(
        filename: String,
        mimeType: String,
        title: String,
        player: String,
        notes: String
    ) async throws -> StreamingUploadResponse {
        try await request(
            "api/app/uploads",
            method: "POST",
            body: [
                "filename": filename,
                "mime_type": mimeType,
                "title": title,
                "player": player,
                "notes": notes
            ]
        )
    }

    func download(path: String) async throws -> URL {
        var request = URLRequest(url: url(for: path))
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
