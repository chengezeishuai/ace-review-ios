import Foundation

struct LoginResponse: Decodable {
    let username: String
    let mustChangePassword: Bool
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case username
        case mustChangePassword = "must_change_password"
        case accessToken = "access_token"
    }
}

struct PasswordChangeResponse: Decodable {
    let username: String
    let mustChangePassword: Bool
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case username
        case mustChangePassword = "must_change_password"
        case accessToken = "access_token"
    }
}

struct TaskItem: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let player: String?
    let originalName: String
    let sizeBytes: Int64
    let uploadedBytes: Int64
    let analysisMode: String?
    let status: String
    let stage: String
    let progress: Int
    let clientMessage: String
    let createdAt: String
    let reportURL: String?
    let pdfURL: String?
    let videoURL: String?
    let pngURL: String?
    let rallyURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, player, status, stage, progress
        case analysisMode = "analysis_mode"
        case originalName = "original_name"
        case sizeBytes = "size_bytes"
        case uploadedBytes = "uploaded_bytes"
        case clientMessage = "client_message"
        case createdAt = "created_at"
        case reportURL = "report_url"
        case pdfURL = "pdf_url"
        case videoURL = "video_url"
        case pngURL = "png_url"
        case rallyURL = "rally_url"
    }

    var isComplete: Bool { status == "completed" }
    var isActive: Bool { ["uploading", "queued", "processing"].contains(status) }
    var failureReason: String {
        let message = clientMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty || message == "分析未能完成，请稍后重试" {
            return "分析过程遇到异常，可点击重新分析后继续"
        }
        return message
    }
}

struct TaskEnvelope: Decodable {
    let task: TaskItem
}

struct ReportMetric: Decodable, Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

struct ReportSummary: Decodable {
    let taskID: String
    let reportAvailable: Bool
    let analysisMode: String
    let summary: String
    let metrics: [ReportMetric]

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case reportAvailable = "report_available"
        case analysisMode = "analysis_mode"
        case summary, metrics
    }

    /// Only exposes a score when the report contract actually returned one.
    var overallScore: Double? {
        let labels = ["综合评分", "综合得分", "总分", "评分"]
        guard let metric = metrics.first(where: { labels.contains($0.label) }) else { return nil }
        let match = metric.value.range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression)
        return match.flatMap { Double(metric.value[$0]) }
    }
}

struct EvidenceCreateResponse: Decodable {
    let task: TaskReference
    let frameCount: Int

    enum CodingKeys: String, CodingKey {
        case task
        case frameCount = "frame_count"
    }
}

struct TaskReference: Decodable {
    let id: String
    let status: String
}

private struct UploadTaskReference: Decodable {
    let id: String
}

struct StreamingUploadResponse: Decodable {
    // Upload scheduling only needs the server-generated id. Keeping this
    // separate from the display task contract prevents optional task fields
    // from ever blocking the first part request.
    let task: UploadTaskReference
    let partSize: Int
    let uploadToken: String

    enum CodingKeys: String, CodingKey {
        case task
        case partSize = "part_size"
        case uploadToken = "upload_token"
    }
}

struct APIErrorBody: Decodable {
    let detail: String
}

struct EmptyResponse: Decodable {}

struct MembershipItem: Decodable, Identifiable {
    let userID: String
    let organizationID: String
    let roleCode: String
    let name: String
    let kind: String

    var id: String { "\(organizationID)-\(roleCode)" }
    enum CodingKeys: String, CodingKey {
        case name, kind
        case userID = "user_id"
        case organizationID = "organization_id"
        case roleCode = "role_code"
    }
}

struct MembershipEnvelope: Decodable { let memberships: [MembershipItem] }

struct EntitlementItem: Decodable, Identifiable {
    let id: String
    let planCode: String
    let cloudRemaining: Int
    let localRemaining: Int
    let ownerName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case planCode = "plan_code"
        case cloudRemaining = "cloud_remaining"
        case localRemaining = "local_remaining"
        case ownerName = "owner_name"
    }
}

struct EntitlementEnvelope: Decodable { let entitlements: [EntitlementItem] }

struct CommerceProduct: Decodable, Identifiable {
    let code: String
    let name: String
    let priceCent: Int
    let cloudCredits: Int
    let localCredits: Int
    let productType: String

    var id: String { code }
    enum CodingKeys: String, CodingKey {
        case code, name
        case priceCent = "price_cent"
        case cloudCredits = "cloud_credits"
        case localCredits = "local_credits"
        case productType = "product_type"
    }
}

struct CommerceOrder: Decodable {
    let orderID: String
    let entitlementID: String
    let cloudCredits: Int
    let localCredits: Int

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case entitlementID = "entitlement_id"
        case cloudCredits = "cloud_credits"
        case localCredits = "local_credits"
    }
}

struct CommerceOrderHistoryItem: Decodable, Identifiable {
    let id: String
    let productCode: String
    let beneficiaryName: String
    let status: String
    let paidAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case productCode = "product_code"
        case beneficiaryName = "beneficiary_name"
        case paidAt = "paid_at"
    }
}

struct CoachComment: Decodable, Identifiable {
    let id: String
    let content: String
    let authorName: String
    let createdAt: String
    enum CodingKeys: String, CodingKey { case id, content; case authorName = "author_name"; case createdAt = "created_at" }
}

struct CoachCommentEnvelope: Decodable { let comments: [CoachComment] }

struct TrainingPlan: Decodable, Identifiable {
    let id: String
    let title: String
    let goal: String
    let status: String
    let startsOn: String?
    let endsOn: String?
    let itemsJSON: String
    enum CodingKeys: String, CodingKey {
        case id, title, goal, status
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case itemsJSON = "items_json"
    }
    var items: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(itemsJSON.utf8))) ?? []
    }
}

struct TrainingPlanEnvelope: Decodable { let plans: [TrainingPlan] }

struct ProgressSummary: Decodable {
    let totalCompleted: Int
    let cloudCompleted: Int
    let localCompleted: Int
    enum CodingKeys: String, CodingKey {
        case totalCompleted = "total_completed"
        case cloudCompleted = "cloud_completed"
        case localCompleted = "local_completed"
    }
}

struct UploadManifest: Codable {
    let taskID: String
    let uploadToken: String
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
    var preparationPercent: Int = 0
    var isShowingPreparation = false
    var message = ""
}

enum TaskLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
