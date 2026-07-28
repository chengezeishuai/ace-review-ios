import QuickLook
import SwiftUI

struct TaskListView: View {
    @ObservedObject var taskStore: TaskStore
    @State private var preview: PreviewFile?
    @State private var reportError = ""

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
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
                                isRetrying: taskStore.retryingTaskIDs.contains(task.id),
                                retry: {
                                    Task { await taskStore.retry(task) }
                                }
                            ) {
                                guard let path = task.pdfURL else { return }
                                Task {
                                    if let url = try? await APIClient.shared.download(
                                        path: path
                                    ) {
                                        preview = PreviewFile(url: url)
                                    } else {
                                        reportError = "报告下载失败，请检查网络后重试"
                                    }
                                }
                            }
                        }
                    }
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
        .alert("无法打开报告", isPresented: Binding(
            get: { !reportError.isEmpty },
            set: { if !$0 { reportError = "" } }
        )) {
            Button("知道了", role: .cancel) { reportError = "" }
        } message: {
            Text(reportError)
        }
        .task {
            while !Task.isCancelled {
                await taskStore.load()
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }
}

private struct TaskCard: View {
    let task: TaskItem
    let isRetrying: Bool
    let retry: () -> Void
    let openReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ACETheme.green.opacity(0.10))
                    Image(systemName: "play.fill")
                        .foregroundStyle(ACETheme.green)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(ACETheme.ink)
                        .lineLimit(2)
                    Text(task.player?.isEmpty == false ? task.player! : task.originalName)
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
                        Text(task.clientMessage)
                        Spacer()
                        Text("\(task.progress)%")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ACETheme.green)
                    ProgressView(value: Double(task.progress), total: 100)
                        .tint(ACETheme.green)
                }
            } else if task.isComplete, task.pdfURL != nil {
                Button(action: openReport) {
                    HStack {
                        Image(systemName: "doc.richtext.fill")
                        Text("查看 PDF 报告")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(ACETheme.green)
                }
            } else if task.status == "failed" {
                VStack(alignment: .leading, spacing: 12) {
                    Text(task.clientMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button(action: retry) {
                        HStack {
                            if isRetrying { ProgressView().controlSize(.small) }
                            Image(systemName: "arrow.clockwise")
                            Text(isRetrying ? "正在重新排队" : "重新分析")
                            Spacer()
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(ACETheme.green)
                    }
                    .disabled(isRetrying)
                }
            }
        }
        .aceCard()
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(task.isComplete ? ACETheme.green : ACETheme.ink)
            .background(
                task.isComplete
                    ? ACETheme.green.opacity(0.10)
                    : ACETheme.lime.opacity(0.45)
            )
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
}

private struct PreviewFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: QLPreviewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(
            in controller: QLPreviewController
        ) -> Int { 1 }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as NSURL
        }
    }
}
