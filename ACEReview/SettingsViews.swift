import Photos
import SwiftUI
import UniformTypeIdentifiers

struct ProfileDetailsView: View {
    let username: String

    var body: some View {
        Form {
            Section("账号") {
                LabeledContent("用户名", value: username.isEmpty ? "ACE 用户" : username)
                LabeledContent("产品", value: "ACE Review")
            }
            Section("资料") {
                Text("训练记录、报告与视频仅在账号授权范围内显示。")
                    .font(.footnote).foregroundStyle(ACETheme.muted)
            }
        }
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PhotoBackupSettingsView: View {
    @AppStorage("ace.mediaBackupEnabled") private var backupEnabled = false
    @AppStorage("ace.mediaBackupVideosOnly") private var videosOnly = true
    @State private var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var showConsent = false
    @StateObject private var backup = MediaBackupService.shared

    var body: some View {
        Form {
            Section("媒体备份") {
                Toggle("启用照片与视频备份", isOn: Binding(
                    get: { backupEnabled },
                    set: { enabled in
                        if enabled { showConsent = true } else { backupEnabled = false }
                    }
                ))
                Text(statusText).font(.footnote).foregroundStyle(ACETheme.muted)
            }
            if backupEnabled {
                Section("备份范围") {
                    Toggle("仅备份视频", isOn: $videosOnly)
                    Text(videosOnly ? "将同步系统照片授权范围内的视频。" : "将同步系统照片授权范围内的照片和视频。")
                        .font(.footnote).foregroundStyle(ACETheme.muted)
                }
                Section("同步状态") {
                    LabeledContent("已备份", value: "\(backup.completedCount) 项")
                    if backup.isRunning {
                        ProgressView(value: backup.progress)
                        Text(backup.statusMessage).font(.footnote).foregroundStyle(ACETheme.muted)
                        Button("停止本次备份", role: .destructive) { backup.stop() }
                    } else {
                        Button("开始备份") { backup.start(videosOnly: videosOnly) }
                            .disabled(!canStart)
                    }
                    if !backup.lastError.isEmpty {
                        Text(backup.lastError).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            Section("隐私说明") {
                Text("备份必须由你明确开启。系统照片权限只用于读取你授权的媒体，应用不会因为取得权限而自动上传全部照片或视频。")
                    .font(.footnote)
            }
        }
        .navigationTitle("隐私与数据")
        .navigationBarTitleDisplayMode(.inline)
        .alert("启用媒体备份？", isPresented: $showConsent) {
            Button("继续", role: .none) { requestAuthorization() }
            Button("取消", role: .cancel) { backupEnabled = false }
        } message: {
            Text("启用后，应用只会按你确认的范围与网络策略同步媒体。你可随时在此页面关闭。")
        }
        .onAppear { authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite) }
    }

    private var canStart: Bool {
        authorization == .authorized || authorization == .limited
    }

    private var statusText: String {
        switch authorization {
        case .authorized, .limited: return backupEnabled ? "已启用，等待选择同步范围。" : "相册已授权，尚未启用备份。"
        case .denied, .restricted: return "相册访问未授权，请在系统设置中开启。"
        default: return "启用后将请求系统照片权限。"
        }
    }

    private func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                authorization = status
                backupEnabled = status == .authorized || status == .limited
            }
        }
    }
}

@MainActor
final class MediaBackupService: ObservableObject {
    static let shared = MediaBackupService()

    @Published private(set) var isRunning = false
    @Published private(set) var completedCount = UserDefaults.standard.integer(forKey: "ace.mediaBackupCompletedCount")
    @Published private(set) var progress = 0.0
    @Published private(set) var statusMessage = "尚未开始备份"
    @Published private(set) var lastError = ""

    private var task: Task<Void, Never>?
    private let completedIDsKey = "ace.mediaBackupCompletedIdentifiers"
    private let partSize = 8 * 1024 * 1024

    func start(videosOnly: Bool) {
        guard !isRunning else { return }
        lastError = ""
        isRunning = true
        task = Task { [weak self] in
            await self?.run(videosOnly: videosOnly)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        statusMessage = "本次备份已停止"
    }

    private func run(videosOnly: Bool) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            lastError = "需要先在系统中授权照片访问权限"
            isRunning = false
            return
        }
        var completed = Set(UserDefaults.standard.stringArray(forKey: completedIDsKey) ?? [])
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if videosOnly {
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        } else {
            options.predicate = NSPredicate(
                format: "mediaType == %d OR mediaType == %d",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaType.video.rawValue
            )
        }
        let assets = PHAsset.fetchAssets(with: options)
        let pending = (0..<assets.count).compactMap { assets.object(at: $0) }.filter { !completed.contains($0.localIdentifier) }
        guard !pending.isEmpty else {
            progress = 1
            statusMessage = "授权范围内的媒体已备份"
            isRunning = false
            return
        }
        for (offset, asset) in pending.enumerated() {
            guard !Task.isCancelled else { break }
            statusMessage = "正在备份第 \(offset + 1)/\(pending.count) 项"
            do {
                try await backup(asset)
                completed.insert(asset.localIdentifier)
                UserDefaults.standard.set(Array(completed), forKey: completedIDsKey)
                completedCount = completed.count
                UserDefaults.standard.set(completedCount, forKey: "ace.mediaBackupCompletedCount")
                progress = Double(offset + 1) / Double(pending.count)
            } catch is CancellationError {
                break
            } catch {
                lastError = error.localizedDescription
                break
            }
        }
        isRunning = false
        if lastError.isEmpty && !Task.isCancelled { statusMessage = "本次备份完成" }
    }

    private func backup(_ asset: PHAsset) async throws {
        try Task.checkCancellation()
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizePhoto || $0.type == .photo }) else {
            throw APIClientError.server("无法读取这项媒体")
        }
        let filename = resource.originalFilename.isEmpty ? "media-\(UUID().uuidString)" : resource.originalFilename
        let mime = UTType(resource.uniformTypeIdentifier)?.preferredMIMEType ?? "application/octet-stream"
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let size = try await export(resource, to: temporary)
        try Task.checkCancellation()
        let remote = try await APIClient.shared.createMediaBackup(filename: filename, mimeType: mime, assetIdentifier: asset.localIdentifier)
        if remote.completed { return }
        let handle = try FileHandle(forReadingFrom: temporary)
        defer { try? handle.close() }
        var index = 0
        while let data = try handle.read(upToCount: remote.partSize), !data.isEmpty {
            try Task.checkCancellation()
            try await APIClient.shared.uploadMediaBackupPart(backupID: remote.id, index: index, data: data)
            index += 1
        }
        guard size > 0, index > 0 else { throw APIClientError.server("媒体内容为空") }
        try await APIClient.shared.finalizeMediaBackup(backupID: remote.id, size: size, totalParts: index)
    }

    private func export(_ resource: PHAssetResource, to destination: URL) async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            FileManager.default.createFile(atPath: destination.path, contents: nil)
            guard let handle = try? FileHandle(forWritingTo: destination) else {
                continuation.resume(throwing: APIClientError.server("无法创建备份缓存"))
                return
            }
            var total: Int64 = 0
            var writeError: Error?
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { data in
                guard writeError == nil else { return }
                do { try handle.write(contentsOf: data); total += Int64(data.count) }
                catch { writeError = error }
            }, completionHandler: { error in
                try? handle.close()
                if let writeError { continuation.resume(throwing: writeError) }
                else if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: total) }
            })
        }
    }
}

struct SupportView: View {
    var body: some View {
        List {
            Section("使用帮助") {
                Label("上传清晰、完整的击球视频", systemImage: "video")
                Label("分析中可离开任务页，应用会持续刷新状态", systemImage: "arrow.triangle.2.circlepath")
                Label("报告生成后可查看网页报告和 PDF", systemImage: "doc.text")
            }
            Section("服务状态") {
                LabeledContent("分析服务", value: "云端处理")
                LabeledContent("数据同步", value: "账号私有")
            }
        }
        .navigationTitle("帮助与支持")
        .navigationBarTitleDisplayMode(.inline)
    }
}
