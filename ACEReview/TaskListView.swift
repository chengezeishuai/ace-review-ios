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
        .sheet(item: $preview) { file in
            QuickLookPreview(url: file.url)
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
        .task {
            while !Task.isCancelled {
                await taskStore.load()
                try? await Task.sleep(for: .seconds(8))
            }
        }
        .onChange(of: uploads.activeTaskID) { _, taskID in
            guard taskID != nil else { return }
            Task { await taskStore.load() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("MY REVIEWS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.3)
                .foregroundStyle(ACETheme.green)
            Text("训练复盘")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(ACETheme.ink)
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
        } else {
            ForEach(taskStore.tasks) { task in
                TaskCard(
                    task: task,
                    isWorking: taskStore.workingTaskIDs.contains(task.id),
                    openPDF: { openPDF(task) },
                    openHTML: { openHTML(task) },
                    openRally: { openRally(task) },
                    retry: { Task { await taskStore.retry(task) } },
                    reanalyze: { reanalyzeTask = task },
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

private struct TaskCard: View {
    @EnvironmentObject private var uploads: UploadManager
    let task: TaskItem
    let isWorking: Bool
    let openPDF: () -> Void
    let openHTML: () -> Void
    let openRally: () -> Void
    let retry: () -> Void
    let reanalyze: () -> Void
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(activeMessage)
                        Spacer()
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
                }
            } else if task.isComplete {
                reportButtons
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

            Divider()
            Button(role: .destructive, action: delete) {
                actionLabel("删除任务", icon: "trash")
                    .foregroundStyle(.red)
            }
            .disabled(task.status == "processing" || isWorking)
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
        uploads.activeTaskID == task.id ? uploads.snapshot : nil
    }

    private var activeMessage: String {
        guard let localSnapshot else { return task.clientMessage }
        if localSnapshot.isShowingPreparation {
            return "因苹果安全限制，正在加密您选择的视频，加密准备完成后将高速上传并开始分析"
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
