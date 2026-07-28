import Foundation

struct LoginResponse: Decodable {
    let ok: Bool
    let username: String
    let mustChangePassword: Bool
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case ok, username
        case mustChangePassword = "must_change_password"
        case accessToken = "access_token"
    }
}

struct PasswordChangeResponse: Decodable {
    let ok: Bool
    let username: String
    let mustChangePassword: Bool
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case ok, username
        case mustChangePassword = "must_change_password"
        case accessToken = "access_token"
    }
}

struct TaskItem: Identifiable, Decodable {
    let id: String
    let title: String
    let player: String?
    let originalName: String
    let sizeBytes: Int64
    let uploadedBytes: Int64
    let status: String
    let stage: String
    let progress: Int
    let clientMessage: String
    let createdAt: String
    let reportURL: String?
    let pdfURL: String?
    let pngURL: String?
    let rallyURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, player, status, stage, progress
        case originalName = "original_name"
        case sizeBytes = "size_bytes"
        case uploadedBytes = "uploaded_bytes"
        case clientMessage = "client_message"
        case createdAt = "created_at"
        case reportURL = "report_url"
        case pdfURL = "pdf_url"
        case pngURL = "png_url"
        case rallyURL = "rally_url"
    }

    var isComplete: Bool { status == "completed" }
    var isActive: Bool { ["uploading", "queued", "processing"].contains(status) }
}

struct TaskEnvelope: Decodable {
    let task: TaskItem
}

struct StreamingUploadResponse: Decodable {
    let task: TaskItem
    let partSize: Int

    enum CodingKeys: String, CodingKey {
        case task
        case partSize = "part_size"
    }
}

struct APIErrorBody: Decodable {
    let detail: String
}

struct EmptyResponse: Decodable {}

struct UploadManifest: Codable {
    let taskID: String
    let assetIdentifier: String
    let filename: String
    let createdAt: Date
    let partSize: Int
    var totalBytes: Int64
    var totalParts: Int
    var generatedParts: Set<Int>
    var completedParts: Set<Int>
    var importFinished: Bool
    var finalizeScheduled: Bool
}

enum UploadPhase: String, Codable {
    case idle
    case reading = "正在读取视频"
    case uploading = "正在后台上传"
    case finalizing = "正在提交分析"
    case completed = "视频已提交"
    case failed = "提交遇到问题"
}

struct UploadSnapshot {
    var phase: UploadPhase = .idle
    var filename = ""
    var bytesRead: Int64 = 0
    var bytesUploaded: Int64 = 0
    var totalBytes: Int64 = 0
    var message = ""
}

enum TaskLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
