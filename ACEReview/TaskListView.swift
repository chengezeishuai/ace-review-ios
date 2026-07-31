import QuickLook
import SwiftUI

struct TaskListView: View {
    @ObservedObject var taskStore: TaskStore
    @EnvironmentObject private var uploads: UploadManager
    @State private var preview: PreviewFile?
    @State private var webPage: WebPage?
    @State private var reportError = ""
    @State private var reanalyzeTask: TaskItem?
    @State private var deleteTask: TaskItem?
    @State private var renameTask: TaskItem?
    @State private var renameTitle = ""
    @State private var collaborationTask: TaskItem?
    @State private var reportTask: TaskItem?
    @State private var filter = TaskFilter.all

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    header
                    content
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .refreshable { await taskStore.load() }
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $reportTask) { task in
            ReportDetailView(
                task: task,
                openPDF: { openPDF(task) },
                openHTML: { openHTML(task) },
                openRally: { openRally(task) },
                collaborate: { collaborationTask = task },
                reanalyze: { reanalyzeTask = task }
            )
        }
        .sheet(item: $preview) { file in
            NavigationStack {
                QuickLookPreview(url: file.url)
                    .navigationTitle("PDF 报告")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: file.url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
            }
        }
        .sheet(item: $webPage) { page in
            NavigationStack {
                AuthenticatedWebView(path: page.path)
                    .navigationTitle(page.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: $reanalyzeTask) { task in
            ReanalyzeSheet { focus, label in
                Task { await taskStore.reanalyze(task, focus: focus, label: label) }
            }
        }
        .alert("无法打开报告", isPresented: Binding(
            get: { !reportError.isEmpty },
            set: { if !$0 { reportError = "" } }
        )) {
            Button("知道了", role: .cancel) { reportError = "" }
        } message: {
            Text(reportError)
        }
        .confirmationDialog(
            "删除这条训练复盘？",
            isPresented: Binding(
                get: { deleteTask != nil },
                set: { if !$0 { deleteTask = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                guard let task = deleteTask else { return }
                deleteTask = nil
                Task { await taskStore.delete(task) }
            }
            Button("取消", role: .cancel) { deleteTask = nil }
        } message: {
            Text("原始视频和分析结果都会从当前账号中移除。")
        }
        .sheet(item: $collaborationTask) { task in
            CollaborationSheet(task: task)
        }
        .alert(
            "重命名训练",
            isPresented: Binding(
                get: { renameTask != nil },
                set: {
                    if !$0 {
                        renameTask = nil
                        renameTitle = ""
                    }
                }
            )
        ) {
            TextField("训练名称", text: $renameTitle)
            Button("保存") {
                guard let task = renameTask else { return }
                let title = renameTitle
                renameTask = nil
                renameTitle = ""
                Task { await taskStore.rename(task, title: title) }
            }
            .disabled(
                renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            Button("取消", role: .cancel) {
                renameTask = nil
                renameTitle = ""
            }
        } message: {
            Text("修改后，Web 端和其他设备会同步显示新名称。")
        }
        .task {
            while !Task.isCancelled {
                await taskStore.load()
                try? await Task.sleep(for: .seconds(8))
            }
        }
        .onChange(of: uploads.snapshots.count) { _, count in
            guard count > 0 else { return }
            Task { await taskStore.load() }
        }
        .onChange(of: uploads.completionCounter) {
            Task { await taskStore.load() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    ACEBrandMark(size: 28)
                    Text("ACE 复盘")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(ACETheme.green)
                }
                Spacer()
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ACETheme.ink)
            }
            Text("任务库")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(ACETheme.ink)
            Picker("任务状态", selection: $filter) {
                ForEach(TaskFilter.allCases) { item in Text(item.title).tag(item) }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var content: some View {
        if taskStore.isLoading && taskStore.tasks.isEmpty {
            ProgressView("正在加载复盘")
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else if !taskStore.errorMessage.isEmpty && taskStore.tasks.isEmpty {
            ContentUnavailableView(
                "暂时无法加载",
                systemImage: "wifi.exclamationmark",
                description: Text(taskStore.errorMessage)
            )
            .padding(.top, 70)
        } else if taskStore.tasks.isEmpty {
            ContentUnavailableView(
                "还没有训练复盘",
                systemImage: "tennisball",
                description: Text("提交第一段训练录像后，进度会显示在这里。")
            )
            .padding(.top, 80)
        } else if filteredTasks.isEmpty {
            ContentUnavailableView("暂无此类任务", systemImage: "line.3.horizontal.decrease.circle", description: Text("切换筛选条件查看其它任务。"))
                .padding(.top, 56)
        } else {
            ForEach(filteredTasks) { task in
                TaskLibraryCard(
                    task: task,
                    isWorking: taskStore.workingTaskIDs.contains(task.id),
                    openReport: { if task.isComplete { reportTask = task } },
                    openPDF: { openPDF(task) },
                    retry: { Task { await taskStore.retry(task) } },
                    rename: {
                        renameTitle = task.title
                        renameTask = task
                    },
                    delete: { deleteTask = task }
                )
            }
        }
    }

    private func openPDF(_ task: TaskItem) {
        guard let path = task.pdfURL else { return }
        Task {
            do {
                preview = PreviewFile(url: try await APIClient.shared.download(path: path))
            } catch {
                reportError = "PDF 报告下载失败，请检查网络后重试"
            }
        }
    }

    private func openHTML(_ task: TaskItem) {
        guard let path = task.reportURL else { return }
        webPage = WebPage(title: "复盘报告", path: path)
    }

    private func openRally(_ task: TaskItem) {
        guard let path = task.rallyURL else { return }
        webPage = WebPage(title: "Rally 回合", path: path)
    }
}

private enum TaskFilter: String, CaseIterable, Identifiable {
    case all, ready, processing, completed

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "全部"
        case .ready: "待处理"
        case .processing: "分析中"
        case .completed: "已完成"
        }
    }

    func matches(_ task: TaskItem) -> Bool {
        switch self {
        case .all: true
        case .ready: ["uploading", "queued", "failed"].contains(task.status)
        case .processing: task.status == "processing"
        case .completed: task.isComplete
        }
    }
}

private struct TaskLibraryCard: View {
    let task: TaskItem
    let isWorking: Bool
    let openReport: () -> Void
    let openPDF: () -> Void
    let retry: () -> Void
    let rename: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: openReport) {
            HStack(spacing: 13) {
                taskVisual
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .foregroundStyle(ACETheme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        statusBadge
                    }
                    Text(task.player?.isEmpty == false ? task.player! : "训练复盘")
                        .font(.caption)
                        .foregroundStyle(ACETheme.muted)
                        .lineLimit(1)
                    if task.isActive {
                        ProgressView(value: Double(task.progress), total: 100)
                            .tint(ACETheme.green)
                        Text("\(task.progress)% · \(stageName)")
                            .font(.caption2)
                            .foregroundStyle(ACETheme.muted)
                    } else if task.isComplete {
                        Text("报告已生成 · 点击查看详情")
                            .font(.caption)
                            .foregroundStyle(ACETheme.green)
                    } else if task.status == "failed" {
                        Text(task.failureReason)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    } else {
                        Text(stageName).font(.caption).foregroundStyle(ACETheme.muted)
                    }
                }
            }
            .padding(16)
            .background(ACETheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ACETheme.line.opacity(0.8), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if task.isComplete, task.pdfURL != nil {
                Button("下载 PDF 报告", systemImage: "arrow.down.doc") { openPDF() }
            }
            if task.status == "failed" {
                Button("重新分析", systemImage: "arrow.clockwise", action: retry)
                    .disabled(isWorking)
            }
            Button("重命名", systemImage: "pencil", action: rename)
                .disabled(isWorking)
            Button("删除任务", systemImage: "trash", role: .destructive, action: delete)
                .disabled(isWorking)
        }
    }

    private var taskVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(task.isComplete ? ACETheme.green.opacity(0.12) : ACETheme.lime.opacity(0.18))
            Image(systemName: task.isComplete ? "checkmark.circle.fill" : task.status == "failed" ? "exclamationmark.triangle.fill" : "figure.tennis")
                .font(.title2)
                .foregroundStyle(task.status == "failed" ? .red : ACETheme.green)
        }
        .frame(width: 60, height: 60)
    }

    private var statusBadge: some View {
        Text(statusName)
            .font(.caption2.bold())
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(task.isComplete ? ACETheme.green : ACETheme.ink)
            .background(task.isComplete ? ACETheme.green.opacity(0.10) : ACETheme.lime.opacity(0.32))
            .clipShape(Capsule())
    }

    private var statusName: String {
        switch task.status {
        case "completed": "已完成"
        case "processing": "分析中"
        case "queued": "等待分析"
        case "uploading": "上传中"
        case "failed": "需处理"
        default: "已取消"
        }
    }

    private var stageName: String {
        let name = task.stage.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "正在准备" : name
    }
}

private struct ReportDetailView: View {
    let task: TaskItem
    let openPDF: () -> Void
    let openHTML: () -> Void
    let openRally: () -> Void
    let collaborate: () -> Void
    let reanalyze: () -> Void
    @State private var summary: ReportSummary?
    @State private var loadError = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                scoreHeader
                reportStatus
                metricGrid
                actions
            }
            .padding(18)
            .padding(.bottom, 32)
        }
        .background(ACETheme.cream.ignoresSafeArea())
        .navigationTitle("复盘报告")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do { summary = try await APIClient.shared.reportSummary(taskID: task.id) }
            catch { loadError = "报告摘要暂时无法加载，可直接查看完整报告。" }
        }
    }

    private var scoreHeader: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(ACETheme.line, lineWidth: 10)
                Circle().trim(from: 0, to: 1).stroke(ACETheme.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("已完成").font(.caption.bold()).foregroundStyle(ACETheme.green)
                    Text("报告").font(.caption2).foregroundStyle(ACETheme.muted)
                }
            }
            .frame(width: 94, height: 94)
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title).font(.title3.bold()).foregroundStyle(ACETheme.ink)
                Text(task.player?.isEmpty == false ? task.player! : "训练复盘")
                    .font(.subheadline).foregroundStyle(ACETheme.muted)
                Label("分析已完成", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold()).foregroundStyle(ACETheme.green)
            }
            Spacer()
        }
        .aceCard()
    }

    private var reportStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("报告摘要").font(.headline).foregroundStyle(ACETheme.ink)
            Text(summary?.summary ?? (loadError.isEmpty ? "正在读取报告摘要…" : loadError))
                .font(.subheadline).foregroundStyle(ACETheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .aceCard()
    }

    private var metricGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary, !summary.metrics.isEmpty {
                Text("技术指标").font(.headline).foregroundStyle(ACETheme.ink)
                HStack(spacing: 10) {
                    ForEach(summary.metrics.prefix(3)) { metric in
                        reportMetric(title: metric.label, value: metric.value, icon: "chart.line.uptrend.xyaxis")
                    }
                }
            } else {
                HStack(spacing: 10) {
                    reportMetric(title: "任务状态", value: "已完成", icon: "checkmark.circle")
                    reportMetric(title: "分析进度", value: "100%", icon: "chart.line.uptrend.xyaxis")
                    reportMetric(title: "分析模式", value: task.analysisMode == "device_evidence" ? "本地" : "云端", icon: "cloud")
                }
            }
        }
    }

    private func reportMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).foregroundStyle(ACETheme.green)
            Text(value).font(.headline).foregroundStyle(ACETheme.ink)
            Text(title).font(.caption2).foregroundStyle(ACETheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ACETheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ACETheme.line.opacity(0.75), lineWidth: 1) }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if task.reportURL != nil {
                Button(action: openHTML) { PrimaryActionLabel(title: "查看完整报告", systemImage: "doc.text.image") }
                    .buttonStyle(PrimaryButtonStyle())
            }
            if task.pdfURL != nil {
                Button(action: openPDF) { secondaryAction("下载 PDF 报告", icon: "arrow.down.doc") }
            }
            if task.rallyURL != nil {
                Button(action: openRally) { secondaryAction("查看训练回合", icon: "film.stack") }
            }
            Button(action: collaborate) { secondaryAction("报告讨论", icon: "bubble.left.and.bubble.right") }
            Button(action: reanalyze) { secondaryAction("按重点重新分析", icon: "arrow.clockwise") }
        }
    }

    private func secondaryAction(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold())
        }
        .font(.subheadline.bold())
        .foregroundStyle(ACETheme.green)
        .padding(16)
        .background(ACETheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ACETheme.line.opacity(0.75), lineWidth: 1) }
    }
}

private struct CollaborationSheet: View {
    let task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [CoachComment] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                Section("教练点评") {
                    if comments.isEmpty {
                        Text("暂时还没有点评").foregroundStyle(ACETheme.muted)
                    }
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(comment.authorName).font(.caption.bold()).foregroundStyle(ACETheme.green)
                            Text(comment.content).font(.body)
                            Text(comment.createdAt).font(.caption2).foregroundStyle(ACETheme.muted)
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("新增点评") {
                    TextEditor(text: $draft).frame(minHeight: 94)
                    if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundStyle(.red) }
                    Button(isSending ? "正在提交" : "提交点评") { send() }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
            }
            .navigationTitle("报告讨论")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
            .task { await load() }
        }
    }

    private var filteredTasks: [TaskItem] {
        taskStore.tasks.filter { filter.matches($0) }
    }

    private func load() async {
        do { comments = try await APIClient.shared.comments(taskID: task.id).comments }
        catch { errorMessage = "讨论内容暂时无法加载" }
    }

    private func send() {
        isSending = true; errorMessage = ""
        Task {
            do {
                try await APIClient.shared.addComment(taskID: task.id, content: draft)
                draft = ""; await load()
            } catch { errorMessage = error.localizedDescription }
            isSending = false
        }
    }
}

private struct TaskCard: View {
    @EnvironmentObject private var uploads: UploadManager
    let task: TaskItem
    let isWorking: Bool
    let openPDF: () -> Void
    let openHTML: () -> Void
    let openRally: () -> Void
    let collaborate: () -> Void
    let retry: () -> Void
    let reanalyze: () -> Void
    let rename: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ACETheme.green.opacity(0.10))
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "play.fill")
                        .foregroundStyle(ACETheme.green)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(ACETheme.ink)
                        .lineLimit(2)
                    Text(task.player?.isEmpty == false ? task.player! : "原文件：\(task.originalName)")
                        .font(.caption)
                        .foregroundStyle(ACETheme.muted)
                        .lineLimit(1)
                }
                Spacer()
                statusBadge
            }

            if task.isActive {
                activeStatus
            } else if task.isComplete {
                reportButtons
                Button(action: collaborate) {
                    actionLabel("报告讨论", icon: "bubble.left.and.bubble.right")
                }
                Button(action: reanalyze) {
                    actionLabel("按重点重新分析", icon: "scope")
                }
                .disabled(isWorking)
            } else if task.status == "failed" {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("未能完成分析")
                            .font(.subheadline.bold())
                            .foregroundStyle(ACETheme.ink)
                        Text(task.failureReason)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button(action: retry) {
                    actionLabel(isWorking ? "正在重新排队" : "重新分析", icon: "arrow.clockwise")
                }
                .disabled(isWorking)
            }

            Button(action: rename) {
                actionLabel("重命名训练", icon: "pencil")
            }
            .disabled(isWorking)

            Divider()
            Button(role: .destructive, action: delete) {
                actionLabel("删除任务", icon: "trash")
                    .foregroundStyle(.red)
            }
            .disabled(isWorking)
        }
        .aceCard()
    }

    @ViewBuilder
    private var reportButtons: some View {
        if task.reportURL != nil {
            Button(action: openHTML) {
                actionLabel("查看 HTML 报告", icon: "doc.text.image")
            }
        }
        if task.pdfURL != nil {
            Button(action: openPDF) {
                actionLabel("查看 PDF 报告", icon: "doc.richtext.fill")
            }
        }
        if task.rallyURL != nil {
            Button(action: openRally) {
                actionLabel("查看 Rally 回合", icon: "film.stack")
            }
        }
    }

    private func actionLabel(_ title: String, icon: String) -> some View {
        HStack {
            if isWorking { ProgressView().controlSize(.small) }
            Image(systemName: icon)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
        }
        .font(.subheadline.bold())
        .foregroundStyle(ACETheme.green)
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(task.isComplete ? ACETheme.green : ACETheme.ink)
            .background(task.isComplete ? ACETheme.green.opacity(0.10) : ACETheme.lime.opacity(0.45))
            .clipShape(Capsule())
    }

    private var statusText: String {
        switch task.status {
        case "completed": "已完成"
        case "failed": "需处理"
        case "uploading": "上传中"
        case "queued": "排队中"
        default: "分析中"
        }
    }

    private var localSnapshot: UploadSnapshot? {
        uploads.snapshot(for: task.id)
    }

    @ViewBuilder
    private var activeStatus: some View {
        VStack(alignment: .leading, spacing: 15) {
            if task.status == "uploading" {
                uploadProgress
            } else {
                uploadCompleted
            }
            TaskStatusTimeline(
                task: task,
                localMessage: task.status == "uploading" ? activeMessage : nil
            )
        }
    }

    private var uploadProgress: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(activeMessage)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 10)
                if let activeProgress {
                    Text("\(activeProgress)%")
                        .monospacedDigit()
                        .contentTransition(
                            .numericText(value: Double(activeProgress))
                        )
                        .animation(
                            .linear(duration: 0.08),
                            value: activeProgress
                        )
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ACETheme.green)
            if let activeProgress {
                ProgressView(value: Double(activeProgress), total: 100)
                    .tint(ACETheme.green)
                    .animation(
                        .linear(duration: 0.08),
                        value: activeProgress
                    )
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(ACETheme.green)
            }
            Label(
                "上传期间请尽量不要离开 ACE",
                systemImage: "iphone.and.arrow.forward"
            )
            .font(.caption2.weight(.medium))
            .foregroundStyle(ACETheme.muted)
        }
        .padding(13)
        .background(ACETheme.green.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var uploadCompleted: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(ACETheme.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("原视频上传完成")
                    .font(.subheadline.bold())
                    .foregroundStyle(ACETheme.ink)
                Text("可以离开 ACE，云端将继续分析")
                    .font(.caption)
                    .foregroundStyle(ACETheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(ACETheme.green.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var activeMessage: String {
        guard let localSnapshot else { return task.clientMessage }
        if localSnapshot.isShowingPreparation {
            return "加密中…完成后将高速上传"
        }
        return localSnapshot.message
    }

    private var activeProgress: Int? {
        guard let localSnapshot else {
            return task.progress > 0 ? task.progress : nil
        }
        if localSnapshot.isShowingPreparation {
            return max(1, localSnapshot.preparationPercent)
        }
        switch localSnapshot.phase {
        case .reading:
            return max(1, localSnapshot.preparationPercent)
        case .idle:
            return nil
        case .uploading:
            return min(98, max(1, localSnapshot.preparationPercent))
        case .finalizing:
            return min(99, max(1, localSnapshot.preparationPercent))
        case .completed:
            return 100
        case .failed:
            guard localSnapshot.totalBytes > 0 else { return nil }
            let ratio = Double(localSnapshot.bytesUploaded)
                / Double(localSnapshot.totalBytes)
            return min(100, max(0, Int((ratio * 100).rounded())))
        }
    }
}

private struct TaskStatusTimeline: View {
    let task: TaskItem
    let localMessage: String?

    private let steps = [
        "上传完整原视频",
        "云端校验与排队",
        "筛选有效动作",
        "整理训练回合",
        "逐拍技术分析",
        "生成复盘报告"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("当前状态")
                .font(.caption.bold())
                .foregroundStyle(ACETheme.muted)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                    HStack(alignment: .top, spacing: 11) {
                        VStack(spacing: 0) {
                            stepMarker(index)
                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(connectorColor(after: index))
                                    .frame(width: 2, height: 25)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            if index == currentStep {
                                ShimmeringStatusText(text: title)
                                    .font(.caption.bold())
                                if !currentMessage.isEmpty {
                                    Text(currentMessage)
                                        .font(.caption2)
                                        .foregroundStyle(ACETheme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else {
                                Text(title)
                                    .font(.caption.weight(
                                        index < currentStep ? .semibold : .regular
                                    ))
                                    .foregroundStyle(
                                        index < currentStep
                                            ? ACETheme.green
                                            : ACETheme.muted.opacity(0.55)
                                    )
                            }
                        }
                        .padding(.top, 1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(13)
        .background(ACETheme.cream.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func stepMarker(_ index: Int) -> some View {
        if index < currentStep {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(ACETheme.green)
                .clipShape(Circle())
        } else if index == currentStep {
            Circle()
                .fill(ACETheme.lime)
                .frame(width: 18, height: 18)
                .overlay {
                    Circle()
                        .stroke(ACETheme.green.opacity(0.35), lineWidth: 3)
                        .scaleEffect(1.25)
                }
        } else {
            Circle()
                .fill(ACETheme.muted.opacity(0.16))
                .frame(width: 18, height: 18)
        }
    }

    private func connectorColor(after index: Int) -> Color {
        index < currentStep
            ? ACETheme.green.opacity(0.65)
            : ACETheme.muted.opacity(0.14)
    }

    private var currentStep: Int {
        switch task.status {
        case "uploading":
            return 0
        case "queued":
            return 1
        case "processing":
            switch task.progress {
            case ..<28: return 1
            case 28..<50: return 2
            case 50..<68: return 3
            case 68..<93: return 4
            default: return 5
            }
        default:
            return 5
        }
    }

    private var currentMessage: String {
        if let localMessage {
            let local = localMessage.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if !local.isEmpty { return local }
        }
        let message = task.clientMessage.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !message.isEmpty { return message }
        return task.stage
    }
}

private struct ShimmeringStatusText: View {
    let text: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let duration = 2.2
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let position = elapsed.truncatingRemainder(
                dividingBy: duration
            ) / duration
            let center = -0.35 + position * 1.7
            Text(text)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ACETheme.green,
                            ACETheme.green,
                            ACETheme.lime,
                            Color.white,
                            ACETheme.lime,
                            ACETheme.green,
                            ACETheme.green
                        ],
                        startPoint: UnitPoint(x: center - 0.35, y: 0.5),
                        endPoint: UnitPoint(x: center + 0.35, y: 0.5)
                    )
                )
        }
        .accessibilityLabel(text)
    }
}

private struct ReanalyzeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var focus = ""
    @State private var label = ""
    let submit: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("分析重点") {
                    Text("复用这条任务的原视频，按你填写的重点重新生成一份分析报告，不需要再次上传视频。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("本次重点，例如：正手击球稳定性", text: $focus, axis: .vertical)
                    TextField("名称（选填）", text: $label)
                }
                Section {
                    Button("创建新分析") {
                        submit(focus, label)
                        dismiss()
                    }
                    .disabled(focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("按重点重新分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

private struct WebPage: Identifiable {
    let id = UUID()
    let title: String
    let path: String
}

private struct PreviewFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
