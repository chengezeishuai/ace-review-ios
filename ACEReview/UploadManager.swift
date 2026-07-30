import Combine
import Foundation
import Photos
import UIKit
import UniformTypeIdentifiers
import UserNotifications

private final class PartAccumulator {
    private let directory: URL
    private let partSize: Int
    private let onPart: (Int, URL, Int) -> Void
    private var index: Int
    private var skipBytes: Int64
    private var handle: FileHandle?
    private var currentURL: URL?
    private var currentSize = 0
    private(set) var totalAccepted: Int64

    init(
        directory: URL,
        partSize: Int,
        startingIndex: Int,
        skipBytes: Int64,
        onPart: @escaping (Int, URL, Int) -> Void
    ) {
        self.directory = directory
        self.partSize = partSize
        self.index = startingIndex
        self.skipBytes = skipBytes
        self.totalAccepted = skipBytes
        self.onPart = onPart
    }

    func append(_ incoming: Data) throws {
        var data = incoming
        if skipBytes > 0 {
            let amount = min(Int64(data.count), skipBytes)
            data.removeFirst(Int(amount))
            skipBytes -= amount
            if data.isEmpty { return }
        }
        var offset = 0
        while offset < data.count {
            try openPartIfNeeded()
            let amount = min(partSize - currentSize, data.count - offset)
            try handle?.write(contentsOf: data.subdata(in: offset..<(offset + amount)))
            currentSize += amount
            totalAccepted += Int64(amount)
            offset += amount
            if currentSize == partSize {
                try closePart()
            }
        }
    }

    func finish() throws -> (bytes: Int64, parts: Int) {
        if currentSize > 0 {
            try closePart()
        } else {
            try handle?.close()
            handle = nil
        }
        return (totalAccepted, index)
    }

    private func openPartIfNeeded() throws {
        guard handle == nil else { return }
        let url = directory.appendingPathComponent(
            String(format: "%08d.part", index)
        )
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        currentURL = url
        currentSize = 0
    }

    private func closePart() throws {
        guard let handle, let currentURL else { return }
        try handle.synchronize()
        try handle.close()
        let completedSize = currentSize
        self.handle = nil
        self.currentURL = nil
        currentSize = 0
        onPart(index, currentURL, completedSize)
        index += 1
    }
}

private final class UploadSlot: NSObject, ObservableObject {
    let slotIndex: Int
    let backgroundIdentifier: String

    @Published private(set) var snapshot = UploadSnapshot()
    @Published private(set) var hasActiveUpload = false
    @Published private(set) var activeTaskID: String?
    @Published var lastError = ""

    var backgroundEventsCompletionHandler: (() -> Void)?

    private let lock = NSLock()
    private var manifest: UploadManifest?
    private var resourceRequestID: PHAssetResourceDataRequestID?
    private var importBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var sessionReady = false
    private var preparationTimer: Timer?
    private var preparationStartedAt: Date?

    private static let minimumPreparationDisplay: TimeInterval = 10
    private static let progressTick: TimeInterval = 0.05
    private static let preparationMessage = "加密中…完成后将高速上传"
    private static let uploadMessage = "原视频正在通过加密安全通道上传"

    private lazy var delegateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.ace.review.upload-delegate.\(slotIndex)"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(
            withIdentifier: backgroundIdentifier
        )
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 4
        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: delegateQueue
        )
        sessionReady = true
        return session
    }()

    init(slotIndex: Int) {
        self.slotIndex = slotIndex
        self.backgroundIdentifier = slotIndex == 0
            ? "com.ace.review.background-upload"
            : "com.ace.review.background-upload.secondary"
        super.init()
        manifest = loadManifest()
        if let manifest {
            let restoredUploadedBytes: Int64
            if manifest.totalParts > 0 {
                restoredUploadedBytes = Int64(
                    Double(manifest.totalBytes)
                        * Double(manifest.completedParts.count)
                        / Double(manifest.totalParts)
                )
            } else {
                restoredUploadedBytes = 0
            }
            let preparationElapsed = Date().timeIntervalSince(manifest.createdAt)
            let showPreparation = !manifest.importFinished
                || preparationElapsed < Self.minimumPreparationDisplay
            let actualPercent = manifest.totalBytes > 0
                ? Int(
                    Double(restoredUploadedBytes)
                        / Double(manifest.totalBytes) * 100
                )
                : 0
            let restoredPreparationPercent = showPreparation
                ? Self.preparationPercent(since: manifest.createdAt)
                : max(15, actualPercent)
            preparationStartedAt = manifest.createdAt
            hasActiveUpload = true
            activeTaskID = manifest.taskID
            snapshot = UploadSnapshot(
                phase: manifest.importFinished ? .uploading : .reading,
                filename: manifest.filename,
                bytesRead: manifest.totalBytes,
                bytesUploaded: restoredUploadedBytes,
                totalBytes: manifest.importFinished ? manifest.totalBytes : 0,
                preparationPercent: restoredPreparationPercent,
                isShowingPreparation: showPreparation,
                message: showPreparation
                    ? Self.preparationMessage
                    : Self.uploadMessage
            )
        }
        _ = backgroundSession
        if let manifest {
            startPreparationProgress(startedAt: manifest.createdAt)
        }
        restoreBackgroundTasks()
    }

    func begin(
        asset: PHAsset,
        title: String,
        player: String,
        notes: String
    ) {
        guard !hasActiveUpload else {
            publishError("请等待当前视频提交完成")
            return
        }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = preferredVideoResource(from: resources) else {
            publishError("无法读取这个视频")
            return
        }
        let filename = normalizedFilename(resource.originalFilename)
        let mime = UTType(resource.uniformTypeIdentifier)?.preferredMIMEType
            ?? "video/quicktime"
        let preparationStart = Date()
        preparationStartedAt = preparationStart
        publish {
            self.hasActiveUpload = true
            self.snapshot = UploadSnapshot(
                phase: .reading,
                filename: filename,
                preparationPercent: 1,
                isShowingPreparation: true,
                message: Self.preparationMessage
            )
        }
        startPreparationProgress(startedAt: preparationStart)

        Task {
            do {
                let response = try await APIClient.shared.createStreamingUpload(
                    filename: filename,
                    mimeType: mime,
                    title: title,
                    player: player,
                    notes: notes
                )
                let folder = try self.uploadDirectory(taskID: response.task.id)
                let newManifest = UploadManifest(
                    taskID: response.task.id,
                    assetIdentifier: asset.localIdentifier,
                    filename: filename,
                    createdAt: preparationStart,
                    partSize: response.partSize,
                    totalBytes: 0,
                    totalParts: 0,
                    generatedParts: [],
                    completedParts: [],
                    importFinished: false,
                    finalizeScheduled: false
                )
                self.lock.lock()
                self.manifest = newManifest
                self.persistManifestUnlocked()
                self.lock.unlock()
                self.publish {
                    self.activeTaskID = response.task.id
                }
                self.startReading(
                    asset: asset,
                    resource: resource,
                    directory: folder,
                    manifest: newManifest
                )
            } catch {
                self.publishError(error.localizedDescription)
            }
        }
    }

    func retryFailedParts() {
        lock.lock()
        guard let manifest else {
            lock.unlock()
            return
        }
        let pending = manifest.generatedParts.subtracting(manifest.completedParts)
        lock.unlock()
        for index in pending.sorted() {
            let file = directoryForExistingTask(manifest.taskID)
                .appendingPathComponent(String(format: "%08d.part", index))
            if FileManager.default.fileExists(atPath: file.path) {
                schedulePart(taskID: manifest.taskID, index: index, fileURL: file)
            }
        }
        publish {
            self.lastError = ""
            self.snapshot.phase = .uploading
            self.snapshot.message = "已继续后台上传"
        }
        maybeScheduleFinalize()
    }

    func acknowledgeCompletion() {
        guard !hasActiveUpload, snapshot.phase == .completed else { return }
        snapshot = UploadSnapshot()
    }

    private static func preparationPercent(since startedAt: Date) -> Int {
        let elapsed = max(0, Date().timeIntervalSince(startedAt))
        let ratio = min(1, elapsed / minimumPreparationDisplay)
        return min(15, max(1, 1 + Int((14 * ratio).rounded(.down))))
    }

    private func realProgressTarget() -> Int {
        switch snapshot.phase {
        case .uploading:
            guard snapshot.totalBytes > 0 else {
                return snapshot.preparationPercent
            }
            let ratio = Double(snapshot.bytesUploaded)
                / Double(snapshot.totalBytes)
            return min(98, max(0, Int((ratio * 100).rounded())))
        case .finalizing:
            return 99
        case .completed:
            return 100
        default:
            return snapshot.preparationPercent
        }
    }

    private func startPreparationProgress(startedAt: Date) {
        DispatchQueue.main.async {
            self.preparationTimer?.invalidate()
            self.snapshot.preparationPercent = max(
                self.snapshot.preparationPercent,
                Self.preparationPercent(since: startedAt)
            )
            let timer = Timer(
                timeInterval: Self.progressTick,
                repeats: true
            ) { [weak self] timer in
                guard let self,
                      self.hasActiveUpload,
                      self.snapshot.phase != .failed else {
                    timer.invalidate()
                    self?.preparationTimer = nil
                    return
                }
                let elapsed = Date().timeIntervalSince(startedAt)
                if self.snapshot.isShowingPreparation {
                    self.snapshot.preparationPercent = max(
                        self.snapshot.preparationPercent,
                        Self.preparationPercent(since: startedAt)
                    )
                    if self.snapshot.totalBytes > 0,
                       elapsed >= Self.minimumPreparationDisplay {
                        self.snapshot.isShowingPreparation = false
                        self.snapshot.message = Self.uploadMessage
                    }
                }
                if !self.snapshot.isShowingPreparation {
                    let target = self.realProgressTarget()
                    if target > self.snapshot.preparationPercent {
                        self.snapshot.preparationPercent += 1
                    }
                }
            }
            self.preparationTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopPreparationProgress() {
        DispatchQueue.main.async {
            self.preparationTimer?.invalidate()
            self.preparationTimer = nil
            self.preparationStartedAt = nil
            self.snapshot.isShowingPreparation = false
        }
    }

    func restoreBackgroundTasks() {
        backgroundSession.getAllTasks { [weak self] tasks in
            guard let self else { return }
            self.lock.lock()
            let manifest = self.manifest
            self.lock.unlock()
            guard let manifest else { return }
            let activeDescriptions = Set(tasks.compactMap(\.taskDescription))
            let pending = manifest.generatedParts.subtracting(manifest.completedParts)
            for index in pending.sorted() {
                let prefix = "part|\(manifest.taskID)|\(index)|"
                guard !activeDescriptions.contains(where: { $0.hasPrefix(prefix) }) else {
                    continue
                }
                let file = self.directoryForExistingTask(manifest.taskID)
                    .appendingPathComponent(String(format: "%08d.part", index))
                if FileManager.default.fileExists(atPath: file.path) {
                    self.schedulePart(
                        taskID: manifest.taskID,
                        index: index,
                        fileURL: file
                    )
                }
            }
            if !manifest.importFinished {
                self.resumeInterruptedImport(manifest)
            } else {
                self.maybeScheduleFinalize()
            }
        }
    }

    private func preferredVideoResource(
        from resources: [PHAssetResource]
    ) -> PHAssetResource? {
        resources.first(where: { $0.type == .video })
            ?? resources.first(where: { $0.type == .fullSizeVideo })
            ?? resources.first
    }

    private func startReading(
        asset: PHAsset,
        resource: PHAssetResource,
        directory: URL,
        manifest: UploadManifest
    ) {
        let completedPrefix = contiguousPrefix(manifest.generatedParts)
        let bytesToSkip = Int64(completedPrefix * manifest.partSize)
        let accumulator = PartAccumulator(
            directory: directory,
            partSize: manifest.partSize,
            startingIndex: completedPrefix,
            skipBytes: bytesToSkip
        ) { [weak self] index, fileURL, size in
            self?.partGenerated(index: index, fileURL: fileURL, size: size)
        }
        beginImportBackgroundTime()
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { [weak self] progress in
            self?.publish {
                guard let self else { return }
                _ = progress
                let startedAt = self.preparationStartedAt ?? Date()
                self.snapshot.preparationPercent = max(
                    self.snapshot.preparationPercent,
                    Self.preparationPercent(since: startedAt)
                )
                self.snapshot.message = self.snapshot.isShowingPreparation
                    ? Self.preparationMessage
                    : Self.uploadMessage
            }
        }
        var readFailure: Error?
        resourceRequestID = PHAssetResourceManager.default().requestData(
            for: resource,
            options: options,
            dataReceivedHandler: { [weak self] data in
                do {
                    try accumulator.append(data)
                    self?.publish {
                        self?.snapshot.bytesRead = accumulator.totalAccepted
                        self?.snapshot.message =
                            self?.snapshot.isShowingPreparation == true
                            ? Self.preparationMessage
                            : Self.uploadMessage
                    }
                } catch {
                    readFailure = error
                }
            },
            completionHandler: { [weak self] error in
                guard let self else { return }
                self.endImportBackgroundTime()
                if let error = readFailure ?? error {
                    self.publishError(error.localizedDescription)
                    return
                }
                do {
                    let result = try accumulator.finish()
                    self.lock.lock()
                    self.manifest?.totalBytes = result.bytes
                    self.manifest?.totalParts = result.parts
                    self.manifest?.importFinished = true
                    self.persistManifestUnlocked()
                    self.lock.unlock()
                    self.publish {
                        self.snapshot.phase = .uploading
                        self.snapshot.bytesRead = result.bytes
                        self.snapshot.totalBytes = result.bytes
                        let startedAt = self.preparationStartedAt ?? Date()
                        let elapsed = Date().timeIntervalSince(startedAt)
                        if elapsed >= Self.minimumPreparationDisplay {
                            self.snapshot.isShowingPreparation = false
                            self.snapshot.message = Self.uploadMessage
                        } else {
                            self.snapshot.message = Self.preparationMessage
                        }
                    }
                    self.maybeScheduleFinalize()
                } catch {
                    self.publishError(error.localizedDescription)
                }
            }
        )
    }

    private func resumeInterruptedImport(_ manifest: UploadManifest) {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [manifest.assetIdentifier],
            options: nil
        )
        guard let asset = result.firstObject,
              let resource = preferredVideoResource(
                from: PHAssetResource.assetResources(for: asset)
              ) else {
            publishError("请重新授权相册后继续提交")
            return
        }
        startReading(
            asset: asset,
            resource: resource,
            directory: directoryForExistingTask(manifest.taskID),
            manifest: manifest
        )
    }

    private func partGenerated(index: Int, fileURL: URL, size: Int) {
        lock.lock()
        guard let taskID = manifest?.taskID else {
            lock.unlock()
            return
        }
        manifest?.generatedParts.insert(index)
        persistManifestUnlocked()
        lock.unlock()
        schedulePart(taskID: taskID, index: index, fileURL: fileURL)
    }

    private func schedulePart(taskID: String, index: Int, fileURL: URL) {
        var request = URLRequest(
            url: APIClient.shared.url(
                for: "api/app/uploads/\(taskID)/parts/\(index)"
            )
        )
        request.httpMethod = "PUT"
        request.timeoutInterval = 300
        request.setValue(
            "application/octet-stream",
            forHTTPHeaderField: "Content-Type"
        )
        attachAuthorization(to: &request)
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        task.taskDescription = "part|\(taskID)|\(index)|\(fileURL.path)"
        task.resume()
    }

    private func maybeScheduleFinalize() {
        lock.lock()
        guard var manifest,
              manifest.importFinished,
              manifest.totalParts > 0,
              manifest.completedParts.count == manifest.totalParts,
              !manifest.finalizeScheduled else {
            lock.unlock()
            return
        }
        manifest.finalizeScheduled = true
        self.manifest = manifest
        persistManifestUnlocked()
        lock.unlock()

        do {
            let bodyURL = directoryForExistingTask(manifest.taskID)
                .appendingPathComponent("finalize.json")
            let body: [String: Any] = [
                "size": manifest.totalBytes,
                "total_parts": manifest.totalParts
            ]
            try JSONSerialization.data(withJSONObject: body).write(
                to: bodyURL,
                options: .atomic
            )
            var request = URLRequest(
                url: APIClient.shared.url(
                    for: "api/app/uploads/\(manifest.taskID)/finalize"
                )
            )
            request.httpMethod = "POST"
            request.timeoutInterval = 300
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            attachAuthorization(to: &request)
            let task = backgroundSession.uploadTask(with: request, fromFile: bodyURL)
            task.taskDescription = "finalize|\(manifest.taskID)|-1|\(bodyURL.path)"
            publish {
                self.snapshot.phase = .finalizing
                self.snapshot.message = "视频上传完成，正在提交分析任务"
            }
            task.resume()
        } catch {
            publishError(error.localizedDescription)
        }
    }

    private func attachAuthorization(to request: inout URLRequest) {
        if let token = KeychainStore.get("accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func uploadDirectory(taskID: String) throws -> URL {
        let directory = directoryForExistingTask(taskID)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func directoryForExistingTask(_ taskID: String) -> URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return support.appendingPathComponent("ACEUploads", isDirectory: true)
            .appendingPathComponent(taskID, isDirectory: true)
    }

    private var manifestURL: URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let filename = slotIndex == 0
            ? "ace-upload-manifest.json"
            : "ace-upload-manifest-secondary.json"
        return support.appendingPathComponent(filename)
    }

    private func loadManifest() -> UploadManifest? {
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        return try? JSONDecoder().decode(UploadManifest.self, from: data)
    }

    private func persistManifestUnlocked() {
        guard let manifest,
              let data = try? JSONEncoder().encode(manifest) else { return }
        try? FileManager.default.createDirectory(
            at: manifestURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: manifestURL, options: .atomic)
    }

    private func contiguousPrefix(_ values: Set<Int>) -> Int {
        var index = 0
        while values.contains(index) { index += 1 }
        return index
    }

    private func normalizedFilename(_ filename: String) -> String {
        let path = URL(fileURLWithPath: filename)
        if path.pathExtension.isEmpty {
            return path.deletingPathExtension().lastPathComponent + ".mov"
        }
        return path.lastPathComponent
    }

    private func beginImportBackgroundTime() {
        DispatchQueue.main.async {
            guard self.importBackgroundTask == .invalid else { return }
            self.importBackgroundTask = UIApplication.shared.beginBackgroundTask(
                withName: "ACE video import"
            ) { [weak self] in
                self?.endImportBackgroundTime()
            }
        }
    }

    private func endImportBackgroundTime() {
        DispatchQueue.main.async {
            guard self.importBackgroundTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(self.importBackgroundTask)
            self.importBackgroundTask = .invalid
        }
    }

    private func completeUpload(taskID: String) {
        stopPreparationProgress()
        let folder = directoryForExistingTask(taskID)
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.removeItem(at: manifestURL)
        lock.lock()
        manifest = nil
        lock.unlock()
        publish {
            self.hasActiveUpload = false
            self.activeTaskID = nil
            self.lastError = ""
            self.snapshot.phase = .completed
            self.snapshot.message = "原视频上传完成，云端正在分析"
        }
        let content = UNMutableNotificationContent()
        content.title = "原视频上传完成"
        content.body = "ACE 云端已开始分析你的训练录像"
        let request = UNNotificationRequest(
            identifier: "ace-upload-\(taskID)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func publish(_ changes: @escaping () -> Void) {
        DispatchQueue.main.async(execute: changes)
    }

    private func publishError(_ message: String) {
        stopPreparationProgress()
        publish {
            self.lastError = message
            self.hasActiveUpload = self.manifest != nil
            self.snapshot.phase = .failed
            self.snapshot.message = message
        }
    }
}

extension UploadSlot: URLSessionTaskDelegate, URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard task.taskDescription?.hasPrefix("part|") == true else { return }
        publish {
            self.snapshot.phase = .uploading
            self.snapshot.message = self.snapshot.isShowingPreparation
                ? Self.preparationMessage
                : Self.uploadMessage
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let description = task.taskDescription else { return }
        let fields = description.split(
            separator: "|",
            maxSplits: 3,
            omittingEmptySubsequences: false
        ).map(String.init)
        guard fields.count == 4 else { return }
        let kind = fields[0]
        let taskID = fields[1]
        let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        guard error == nil, (200..<300).contains(status) else {
            lock.lock()
            manifest?.finalizeScheduled = false
            persistManifestUnlocked()
            lock.unlock()
            publishError(error?.localizedDescription ?? "后台上传失败（\(status)）")
            return
        }
        if kind == "part", let index = Int(fields[2]) {
            try? FileManager.default.removeItem(atPath: fields[3])
            lock.lock()
            manifest?.completedParts.insert(index)
            let completed = manifest?.completedParts.count ?? 0
            let total = manifest?.totalParts ?? 0
            let totalBytes = manifest?.totalBytes ?? 0
            persistManifestUnlocked()
            lock.unlock()
            publish {
                if total > 0 {
                    self.snapshot.bytesUploaded = Int64(
                        Double(totalBytes) * Double(completed) / Double(total)
                    )
                }
            }
            maybeScheduleFinalize()
        } else if kind == "finalize" {
            completeUpload(taskID: taskID)
        }
    }

    func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        publish { [weak self] in
            self?.backgroundEventsCompletionHandler?()
            self?.backgroundEventsCompletionHandler = nil
        }
    }
}

final class UploadManager: ObservableObject {
    static let shared = UploadManager()
    static let maximumConcurrentUploads = 2

    @Published private(set) var snapshots: [String: UploadSnapshot] = [:]
    @Published private(set) var activeUploadCount = 0
    @Published private(set) var completionCounter = 0
    @Published private(set) var lastError = ""

    private let slots: [UploadSlot]
    private var cancellables: Set<AnyCancellable> = []
    private var previousActiveTaskIDs: Set<String> = []
    private var reservedSlotIndexes: Set<Int> = []

    var hasActiveUpload: Bool { activeUploadCount > 0 }

    var canStartUpload: Bool {
        activeUploadCount + reservedSlotIndexes.count
            < Self.maximumConcurrentUploads
    }

    var activeFilenames: [String] {
        slots
            .filter(\.hasActiveUpload)
            .map(\.snapshot.filename)
            .filter { !$0.isEmpty }
    }

    private init() {
        slots = (0..<Self.maximumConcurrentUploads).map {
            UploadSlot(slotIndex: $0)
        }
        for slot in slots {
            slot.objectWillChange
                .sink { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.refreshPublishedState()
                    }
                }
                .store(in: &cancellables)
        }
        refreshPublishedState()
    }

    func begin(
        asset: PHAsset,
        title: String,
        player: String,
        notes: String
    ) {
        guard let index = slots.indices.first(where: {
            !slots[$0].hasActiveUpload && !reservedSlotIndexes.contains($0)
        }) else {
            lastError = "最多可同时提交两个视频，请等待其中一个完成"
            return
        }
        reservedSlotIndexes.insert(index)
        slots[index].begin(
            asset: asset,
            title: title,
            player: player,
            notes: notes
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.reservedSlotIndexes.remove(index)
            self.refreshPublishedState()
        }
    }

    func snapshot(for taskID: String) -> UploadSnapshot? {
        snapshots[taskID]
    }

    func retryFailedParts(taskID: String) {
        slots.first(where: { $0.activeTaskID == taskID })?
            .retryFailedParts()
    }

    func restoreBackgroundTasks() {
        slots.forEach { $0.restoreBackgroundTasks() }
    }

    func handleBackgroundEvents(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard let slot = slots.first(where: {
            $0.backgroundIdentifier == identifier
        }) else {
            completionHandler()
            return
        }
        slot.backgroundEventsCompletionHandler = completionHandler
        slot.restoreBackgroundTasks()
    }

    private func refreshPublishedState() {
        let activeSlots = slots.filter(\.hasActiveUpload)
        let pairs: [(String, UploadSnapshot)] = activeSlots.compactMap { slot in
                guard let taskID = slot.activeTaskID else { return nil }
                return (taskID, slot.snapshot)
            }
        let newSnapshots = Dictionary(uniqueKeysWithValues: pairs)
        let activeIDs = Set(newSnapshots.keys)
        if !previousActiveTaskIDs.subtracting(activeIDs).isEmpty {
            completionCounter += 1
        }
        previousActiveTaskIDs = activeIDs
        snapshots = newSnapshots
        activeUploadCount = activeSlots.count
        lastError = activeSlots.compactMap {
            $0.lastError.isEmpty ? nil : $0.lastError
        }.first ?? ""
    }
}
