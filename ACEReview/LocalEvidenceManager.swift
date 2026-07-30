import AVFoundation
import Foundation
import Photos
import UIKit

@MainActor
final class LocalEvidenceManager: ObservableObject {
    static let shared = LocalEvidenceManager()

    @Published private(set) var isWorking = false
    @Published private(set) var progress = 0.0
    @Published private(set) var message = ""
    @Published private(set) var errorMessage = ""

    private struct Manifest: Codable {
        let taskID: String
        let directory: String
        let frameCount: Int
        let duration: Double
        var uploaded: Set<Int>
    }

    private let manifestKey = "ace.localEvidence.manifest"
    private var activeManifest: Manifest?

    private init() {
        activeManifest = loadManifest()
    }

    func begin(asset: PHAsset, title: String, player: String, notes: String) {
        guard !isWorking else { return }
        isWorking = true
        progress = 0.01
        message = "正在设备端提取动作画面"
        errorMessage = ""
        Task {
            do {
                let url = try await assetURL(for: asset)
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try Self.extractFrames(from: url)
                }.value
                progress = 0.28
                message = "正在创建隐私分析任务"
                let response = try await APIClient.shared.createEvidence(
                    title: title, player: player, notes: notes,
                    durationSeconds: prepared.duration, frameCount: prepared.frameCount
                )
                let manifest = Manifest(taskID: response.task.id, directory: prepared.directory.path,
                                        frameCount: prepared.frameCount, duration: prepared.duration, uploaded: [])
                activeManifest = manifest
                saveManifest(manifest)
                try await upload(manifest)
            } catch {
                errorMessage = error.localizedDescription
                message = "本地分析准备未完成"
                isWorking = false
            }
        }
    }

    func resumePendingUpload() {
        guard !isWorking, let manifest = activeManifest else { return }
        isWorking = true
        Task {
            do { try await upload(manifest) }
            catch { errorMessage = error.localizedDescription; isWorking = false }
        }
    }

    private func upload(_ original: Manifest) async throws {
        var manifest = original
        let directory = URL(fileURLWithPath: manifest.directory, isDirectory: true)
        for index in 0..<manifest.frameCount where !manifest.uploaded.contains(index) {
            let frame = directory.appendingPathComponent(String(format: "%05d.jpg", index))
            let data = try Data(contentsOf: frame)
            try await APIClient.shared.uploadEvidenceFrame(taskID: manifest.taskID, index: index, data: data)
            manifest.uploaded.insert(index)
            activeManifest = manifest
            saveManifest(manifest)
            progress = 0.28 + 0.66 * Double(manifest.uploaded.count) / Double(manifest.frameCount)
            message = "正在提交设备端关键画面"
        }
        _ = try await APIClient.shared.finalizeEvidence(taskID: manifest.taskID, durationSeconds: manifest.duration, frameCount: manifest.frameCount)
        try? FileManager.default.removeItem(at: directory)
        UserDefaults.standard.removeObject(forKey: manifestKey)
        activeManifest = nil
        progress = 1
        message = "关键画面已提交，正在生成复盘"
        isWorking = false
    }

    private func assetURL(for asset: PHAsset) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let urlAsset = avAsset as? AVURLAsset { continuation.resume(returning: urlAsset.url) }
                else { continuation.resume(throwing: APIClientError.server("无法读取视频")) }
            }
        }
    }

    nonisolated private static func extractFrames(from url: URL) throws -> (directory: URL, duration: Double, frameCount: Int) {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 1 else { throw APIClientError.server("视频时长不足，无法进行本地分析") }
        let count = min(360, max(8, Int((duration * 4).rounded())))
        let root = try evidenceRoot()
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        for index in 0..<count {
            let seconds = Double(index) * duration / Double(max(1, count - 1))
            let image = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
            guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.78) else {
                throw APIClientError.server("无法生成设备端证据帧")
            }
            try jpeg.write(to: directory.appendingPathComponent(String(format: "%05d.jpg", index)), options: .atomic)
        }
        return (directory, duration, count)
    }

    nonisolated private static func evidenceRoot() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true)
            .appendingPathComponent("ACEEvidence", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func saveManifest(_ manifest: Manifest) {
        UserDefaults.standard.set(try? JSONEncoder().encode(manifest), forKey: manifestKey)
    }

    private func loadManifest() -> Manifest? {
        guard let data = UserDefaults.standard.data(forKey: manifestKey) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }
}
