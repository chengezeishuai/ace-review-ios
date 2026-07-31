import SwiftUI

struct TaskListView: View {
    @ObservedObject var taskStore: TaskStore
    @State private var filter = TaskFilter.all
    @State private var selectedTask: TaskItem?

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    taskFilters
                    if taskStore.isLoading && taskStore.tasks.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
                    } else if visibleTasks.isEmpty {
                        ContentUnavailableView("暂无复盘任务", systemImage: "video", description: Text("提交训练视频后，分析记录会显示在这里。"))
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(visibleTasks) { task in
                                Button { selectedTask = task } label: { LibraryTaskRow(task: task) }
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
        .task { await taskStore.load() }
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
                    ProgressView(value: Double(task.progress), total: 100).tint(ACETheme.green)
                    Text("\(task.progress)% · \(task.clientMessage.isEmpty ? task.stage : task.clientMessage)").font(.caption2).foregroundStyle(ACETheme.muted).lineLimit(1)
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
    private var statusBadge: some View { Text(statusName).font(.caption2.bold()).padding(.horizontal, 9).padding(.vertical, 4).foregroundStyle(statusColor).background(statusColor.opacity(0.11)).clipShape(Capsule()) }
    private var statusName: String { switch task.status { case "completed": "已完成"; case "queued": "待分析"; case "uploading", "processing": "分析中"; default: "失败" } }
    private func formattedDate(_ source: String) -> String { source.replacingOccurrences(of: "T", with: " · ").prefix(16).description }
}

private struct TaskProgressView: View {
    let task: TaskItem
    @ObservedObject var store: TaskStore
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: task.status == "failed" ? "exclamationmark.triangle.fill" : "waveform.path.ecg")
                .font(.system(size: 50)).foregroundStyle(task.status == "failed" ? .red : ACETheme.green)
            Text(task.status == "failed" ? "本次分析未完成" : "正在分析视频")
                .font(.title2.bold()).foregroundStyle(ACETheme.ink)
            Text(task.clientMessage.isEmpty ? task.stage : task.clientMessage).multilineTextAlignment(.center).foregroundStyle(ACETheme.muted)
            if task.status != "failed" { ProgressView(value: Double(task.progress), total: 100).tint(ACETheme.green).padding(.horizontal, 42) }
            if task.status == "failed" { Button("重新分析") { Task { await store.retry(task) } }.buttonStyle(PrimaryButtonStyle()) }
            Spacer()
        }
        .padding(28).background(ACETheme.cream.ignoresSafeArea())
        .navigationTitle("分析状态").navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReviewReportView: View {
    let task: TaskItem
    @State private var summary: ReportSummary?
    @State private var showFullReport = false
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
                Button { showFullReport = true } label: { Label("查看完整报告", systemImage: "doc.text.image").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(20).padding(.bottom, 30)
        }
        .background(ACETheme.cream.ignoresSafeArea())
        .navigationTitle("复盘报告").navigationBarTitleDisplayMode(.inline)
        .task { summary = try? await APIClient.shared.reportSummary(taskID: task.id) }
        .sheet(isPresented: $showFullReport) { NavigationStack { AuthenticatedWebView(path: task.reportURL ?? "api/app/tasks/\(task.id)/report").navigationTitle("完整报告").navigationBarTitleDisplayMode(.inline) } }
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
