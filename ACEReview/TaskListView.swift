import SwiftUI

struct TaskListView: View {
    @ObservedObject var taskStore: TaskStore
    @EnvironmentObject private var uploads: UploadManager
    @State private var filter = TaskFilter.all
    @State private var selectedTask: TaskItem?

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    taskFilters
                    if let snapshot = uploads.snapshots.values.first, snapshot.phase != .idle {
                        liveUploadCard(snapshot)
                    }
                    if !taskStore.errorMessage.isEmpty {
                        Label(taskStore.errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ACETheme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if taskStore.isLoading && taskStore.tasks.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
                    } else if visibleTasks.isEmpty {
                        ContentUnavailableView("暂无复盘任务", systemImage: "video", description: Text("提交训练视频后，分析记录会显示在这里。"))
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(visibleTasks) { task in
                                Button { selectedTask = task } label: {
                                    LibraryTaskRow(task: task, localUpload: uploads.snapshot(for: task.id))
                                }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        if task.status == "failed" { Button("重新分析") { Task { await taskStore.retry(task) } } }
                                        Button("删除记录", role: .destructive) { Task { await taskStore.delete(task) } }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
        }
        .refreshable { await taskStore.load() }
        .task {
            await taskStore.load()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                if taskStore.tasks.contains(where: \.isActive) { await taskStore.load() }
            }
        }
        .navigationDestination(item: $selectedTask) { task in
            if task.isComplete { ReviewReportView(task: task) }
            else { TaskProgressView(task: task, store: taskStore) }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                ACEBrandMark(size: 29)
                Text("ACE Review").font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(ACETheme.green)
            }
            Spacer()
            Image(systemName: "magnifyingglass").foregroundStyle(ACETheme.ink)
        }
        .overlay(alignment: .bottomLeading) {
            Text("任务库")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(ACETheme.ink)
                .offset(y: 46)
        }
        .padding(.bottom, 46)
    }

    private var taskFilters: some View {
        HStack(spacing: 8) {
            ForEach(TaskFilter.allCases) { item in
                Button(item.title) { filter = item }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(filter == item ? .white : ACETheme.ink)
                    .padding(.horizontal, 15).padding(.vertical, 8)
                    .background(filter == item ? ACETheme.green : ACETheme.paper)
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(filter == item ? .clear : ACETheme.line, lineWidth: 1) }
            }
        }
    }

    private var visibleTasks: [TaskItem] {
        taskStore.tasks.filter { filter.matches($0) }
    }

    private func liveUploadCard(_ snapshot: UploadSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label(uploadHeadline(snapshot), systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.bold())
                    .foregroundStyle(ACETheme.ink)
                Spacer()
                Text("\(Int(uploadProgress(snapshot).rounded()))%")
                    .font(.caption.bold())
                    .foregroundStyle(ACETheme.green)
            }
            ProgressView(value: uploadProgress(snapshot), total: 100).tint(ACETheme.green)
            Text(snapshot.message).font(.caption).foregroundStyle(ACETheme.muted)
            HStack(spacing: 7) {
                processTag("准备资源", complete: snapshot.phase != .reading)
                processTag("上传视频", complete: snapshot.phase == .finalizing || snapshot.phase == .completed)
                processTag("云端分析", complete: snapshot.phase == .completed)
            }
        }
        .padding(16)
        .background(ACETheme.green.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(ACETheme.green.opacity(0.22), lineWidth: 1) }
    }

    private func uploadProgress(_ snapshot: UploadSnapshot) -> Double {
        if snapshot.totalBytes > 0 { return Double(snapshot.bytesUploaded) / Double(snapshot.totalBytes) * 100 }
        return Double(snapshot.preparationPercent)
    }

    private func uploadHeadline(_ snapshot: UploadSnapshot) -> String {
        switch snapshot.phase {
        case .reading: return "正在准备视频资源"
        case .uploading: return "正在上传视频"
        case .finalizing: return "上传完成，正在启动分析"
        case .completed: return "云端正在分析"
        default: return snapshot.phase.rawValue
        }
    }

    private func processTag(_ title: String, complete: Bool) -> some View {
        Label(title, systemImage: complete ? "checkmark.circle.fill" : "circle")
            .font(.caption2)
            .foregroundStyle(complete ? ACETheme.green : ACETheme.muted)
    }
}

private enum TaskFilter: String, CaseIterable, Identifiable {
    case all, ready, processing, done
    var id: String { rawValue }
    var title: String { switch self { case .all: "全部"; case .ready: "待分析"; case .processing: "分析中"; case .done: "已完成" } }
    func matches(_ task: TaskItem) -> Bool {
        switch self {
        case .all: return true
        case .ready: return task.status == "queued"
        case .processing: return task.status == "uploading" || task.status == "processing"
        case .done: return task.isComplete
        }
    }
}

private struct LibraryTaskRow: View {
    let task: TaskItem
    let localUpload: UploadSnapshot?
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                TennisCourtThumbnail().frame(width: 108, height: 67)
                Image(systemName: task.isComplete ? "checkmark" : task.status == "failed" ? "exclamationmark" : "play.fill")
                    .font(.caption.bold()).foregroundStyle(.white).padding(6).background(statusColor).clipShape(Circle()).padding(5)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(task.title).font(.subheadline.bold()).lineLimit(1); Spacer(); statusBadge }
                Text(formattedDate(task.createdAt)).font(.caption).foregroundStyle(ACETheme.muted)
                if task.isActive {
                    ProgressView(value: displayedProgress, total: 100).tint(ACETheme.green)
                    Text("\(Int(displayedProgress.rounded()))% · \(displayMessage)").font(.caption2).foregroundStyle(ACETheme.muted).lineLimit(1)
                } else if task.isComplete {
                    Text("报告已生成").font(.caption).foregroundStyle(ACETheme.green)
                } else {
                    Text(task.failureReason).font(.caption).foregroundStyle(.red).lineLimit(1)
                }
            }
        }
        .padding(11)
        .background(ACETheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ACETheme.line.opacity(0.8), lineWidth: 1) }
    }
    private var statusColor: Color { task.isComplete ? ACETheme.green : task.status == "failed" ? .red : ACETheme.green.opacity(0.85) }
    private var displayedProgress: Double {
        guard let localUpload else { return Double(task.progress) }
        if localUpload.totalBytes > 0 { return Double(localUpload.bytesUploaded) / Double(localUpload.totalBytes) * 100 }
        return Double(localUpload.preparationPercent)
    }
    private var displayMessage: String {
        guard let localUpload else { return task.clientMessage.isEmpty ? task.stage : task.clientMessage }
        return localUpload.message
    }
    private var statusBadge: some View { Text(statusName).font(.caption2.bold()).padding(.horizontal, 9).padding(.vertical, 4).foregroundStyle(statusColor).background(statusColor.opacity(0.11)).clipShape(Capsule()) }
    private var statusName: String { switch task.status { case "completed": "已完成"; case "queued": "待分析"; case "uploading", "processing": "分析中"; default: "失败" } }
    private func formattedDate(_ source: String) -> String { source.replacingOccurrences(of: "T", with: " · ").prefix(16).description }
}

private struct TaskProgressView: View {
    @State private var currentTask: TaskItem
    @ObservedObject var store: TaskStore
    @EnvironmentObject private var uploads: UploadManager

    init(task: TaskItem, store: TaskStore) {
        _currentTask = State(initialValue: task)
        self.store = store
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: currentTask.status == "failed" ? "exclamationmark.triangle.fill" : "waveform.path.ecg")
                .font(.system(size: 50)).foregroundStyle(currentTask.status == "failed" ? .red : ACETheme.green)
                .symbolEffect(.variableColor.iterative, isActive: currentTask.isActive)
            Text(currentTask.status == "failed" ? "本次分析未完成" : progressTitle)
                .font(.title2.bold()).foregroundStyle(ACETheme.ink)
            Text(progressMessage).multilineTextAlignment(.center).foregroundStyle(ACETheme.muted)
            if currentTask.status != "failed" {
                ProgressView(value: displayedProgress, total: 100).tint(ACETheme.green).padding(.horizontal, 42)
                Text("\(Int(displayedProgress.rounded()))% · 状态会自动刷新").font(.caption).foregroundStyle(ACETheme.muted)
            }
            if currentTask.status == "failed" { Button("重新分析") { Task { await store.retry(currentTask) } }.buttonStyle(PrimaryButtonStyle()) }
            Spacer()
        }
        .padding(28).background(ACETheme.cream.ignoresSafeArea())
        .navigationTitle("分析状态").navigationBarTitleDisplayMode(.inline)
        .task {
            while !Task.isCancelled && currentTask.isActive {
                if let refreshed = await store.detail(id: currentTask.id) { currentTask = refreshed }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private var localUpload: UploadSnapshot? { uploads.snapshot(for: currentTask.id) }
    private var displayedProgress: Double {
        guard let localUpload else { return Double(currentTask.progress) }
        if localUpload.totalBytes > 0 { return Double(localUpload.bytesUploaded) / Double(localUpload.totalBytes) * 100 }
        return Double(localUpload.preparationPercent)
    }
    private var progressTitle: String {
        if localUpload != nil { return "正在上传训练视频" }
        return currentTask.status == "queued" ? "正在排队分析" : "正在分析视频"
    }
    private var progressMessage: String {
        if let localUpload { return localUpload.message }
        return currentTask.clientMessage.isEmpty ? currentTask.stage : currentTask.clientMessage
    }
}

private struct ReviewReportView: View {
    let task: TaskItem
    @State private var summary: ReportSummary?
    @State private var showFullReport = false
    @State private var showVideo = false
    @State private var showPDF = false
    @State private var loadError = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                scoreHeader
                Text("技术概览").font(.headline).foregroundStyle(ACETheme.ink)
                HStack(spacing: 10) {
                    ForEach((summary?.metrics ?? []).prefix(3)) { metric in
                        VStack(spacing: 7) { Image(systemName: "target").foregroundStyle(ACETheme.green); Text(metric.value).font(.headline); Text(metric.label).font(.caption2).foregroundStyle(ACETheme.muted) }
                            .frame(maxWidth: .infinity).padding(13).background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                Text(summary?.summary ?? "报告正在载入。").font(.subheadline).foregroundStyle(ACETheme.muted).padding(16).background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 14))
                if !loadError.isEmpty {
                    Label(loadError, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                        .background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                VStack(spacing: 10) {
                    if task.videoURL != nil {
                        Button { showVideo = true } label: {
                            Label("查看训练视频", systemImage: "play.rectangle.fill").frame(maxWidth: .infinity)
                        }.buttonStyle(PrimaryButtonStyle())
                    }
                    if task.reportURL != nil {
                        Button { showFullReport = true } label: {
                            Label("查看完整报告", systemImage: "doc.text.image").frame(maxWidth: .infinity)
                        }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        Label("报告文件暂不可用", systemImage: "doc.badge.ellipsis")
                            .font(.footnote).foregroundStyle(ACETheme.muted)
                    }
                    if task.pdfURL != nil {
                        Button { showPDF = true } label: {
                            Label("打开 PDF 报告", systemImage: "arrow.down.doc").frame(maxWidth: .infinity)
                        }
                        .font(.subheadline.bold()).foregroundStyle(ACETheme.green)
                    }
                }
            }
            .padding(20).padding(.bottom, 30)
        }
        .background(ACETheme.cream.ignoresSafeArea())
        .navigationTitle("复盘报告").navigationBarTitleDisplayMode(.inline)
        .task {
            do { summary = try await APIClient.shared.reportSummary(taskID: task.id) }
            catch { loadError = error.localizedDescription }
        }
        .sheet(isPresented: $showFullReport) {
            if let reportURL = task.reportURL {
                NavigationStack { AuthenticatedWebView(path: reportURL).navigationTitle("完整报告").navigationBarTitleDisplayMode(.inline) }
            }
        }
        .sheet(isPresented: $showVideo) {
            if let videoURL = task.videoURL {
                NavigationStack { AuthenticatedWebView(path: videoURL).navigationTitle("训练视频").navigationBarTitleDisplayMode(.inline) }
            }
        }
        .sheet(isPresented: $showPDF) {
            if let pdfURL = task.pdfURL {
                NavigationStack { AuthenticatedWebView(path: pdfURL).navigationTitle("PDF 报告").navigationBarTitleDisplayMode(.inline) }
            }
        }
    }
    private var scoreHeader: some View {
        HStack(spacing: 18) {
            let score = summary?.overallScore
            ZStack { Circle().stroke(ACETheme.line, lineWidth: 9); Circle().trim(from: 0, to: CGFloat((score ?? 0) / 100)).stroke(ACETheme.green, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90)); VStack(spacing: 1) { Text(score.map { String(Int($0.rounded())) } ?? "--").font(.system(size: 32, weight: .bold)); Text("综合评分").font(.caption2) } }
                .frame(width: 112, height: 112).foregroundStyle(ACETheme.green)
            VStack(alignment: .leading, spacing: 5) { Text(task.title).font(.title3.bold()).foregroundStyle(ACETheme.ink); Text(task.player?.isEmpty == false ? task.player! : "训练复盘").font(.caption).foregroundStyle(ACETheme.muted); Label("已完成", systemImage: "checkmark.seal.fill").font(.caption.bold()).foregroundStyle(ACETheme.green) }
            Spacer()
        }
        .padding(17).background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay { RoundedRectangle(cornerRadius: 16).stroke(ACETheme.line, lineWidth: 1) }
    }
}

private struct TennisCourtThumbnail: View {
    var body: some View { ZStack { RoundedRectangle(cornerRadius: 10).fill(ACETheme.green.opacity(0.88)); RoundedRectangle(cornerRadius: 1).stroke(.white.opacity(0.75), lineWidth: 1).padding(12); Rectangle().fill(.white.opacity(0.75)).frame(height: 1) }.clipShape(RoundedRectangle(cornerRadius: 10)) }
}
