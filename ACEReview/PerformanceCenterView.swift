import SwiftUI

struct PerformanceCenterView: View {
    @State private var reports: [ScoredReport] = []
    @State private var isLoading = true
    @State private var message = ""

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("综合分析")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(ACETheme.ink)
                    Text("基于已完成且回传真实技术指标的训练报告。")
                        .font(.subheadline)
                        .foregroundStyle(ACETheme.muted)

                    if isLoading {
                        ProgressView("正在整理训练表现")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else if reports.isEmpty {
                        ContentUnavailableView(
                            "还没有可统计的成绩",
                            systemImage: "chart.bar.xaxis",
                            description: Text(message.isEmpty ? "完成包含技术评分的复盘后，这里会展示综合表现和排名。" : message)
                        )
                        .padding(.vertical, 42)
                    } else {
                        scoreCard
                        rankingCard
                        reportList
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("成绩排名")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var averageScore: Int {
        Int((reports.map(\.score).reduce(0, +) / Double(reports.count)).rounded())
    }

    private var scoreCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(ACETheme.line, lineWidth: 11)
                Circle().trim(from: 0, to: CGFloat(min(averageScore, 100)) / 100)
                    .stroke(ACETheme.green, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(averageScore)").font(.title.bold()).foregroundStyle(ACETheme.ink)
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 5) {
                Text("综合得分").font(.headline).foregroundStyle(ACETheme.ink)
                Text("来自 \(reports.count) 份真实报告").font(.subheadline).foregroundStyle(ACETheme.muted)
                Text("排名会在同组织完成评分的成员之间显示。")
                    .font(.caption).foregroundStyle(ACETheme.muted)
            }
            Spacer()
        }
        .aceCard()
    }

    private var reportList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已计入的训练报告").font(.headline).foregroundStyle(ACETheme.ink)
            ForEach(reports) { report in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.title).font(.subheadline.bold()).foregroundStyle(ACETheme.ink)
                        Text(report.summary).font(.caption).foregroundStyle(ACETheme.muted).lineLimit(2)
                    }
                    Spacer()
                    Text("\(report.score)").font(.title3.bold()).foregroundStyle(ACETheme.green)
                }
                .padding(.vertical, 7)
                if report.id != reports.last?.id { Divider() }
            }
        }
        .aceCard()
    }

    private var rankingCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trophy")
                .font(.title3)
                .foregroundStyle(ACETheme.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("成绩排名").font(.headline).foregroundStyle(ACETheme.ink)
                Text("当前只展示已完成评分的个人表现；同组织排名会在平台返回可比较的真实成绩后显示。")
                    .font(.caption).foregroundStyle(ACETheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .aceCard()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let tasks = try await APIClient.shared.tasks().filter(\.isComplete)
            let results = await withTaskGroup(of: ScoredReport?.self, returning: [ScoredReport].self) { group in
                for task in tasks {
                    group.addTask {
                        guard let summary = try? await APIClient.shared.reportSummary(taskID: task.id) else { return nil }
                        let candidates = summary.metrics.filter { $0.label == "综合评分" || $0.label == "综合得分" }
                        guard let value = candidates.first?.value, let score = Double(value) else { return nil }
                        return ScoredReport(id: task.id, title: task.title, summary: summary.summary, score: score)
                    }
                }
                var values: [ScoredReport] = []
                for await result in group { if let result { values.append(result) } }
                return values.sorted { $0.score > $1.score }
            }
            reports = results
        } catch {
            message = "综合分析暂时无法加载，请稍后重试。"
        }
    }
}

private struct ScoredReport: Identifiable {
    let id: String
    let title: String
    let summary: String
    let score: Double
}
