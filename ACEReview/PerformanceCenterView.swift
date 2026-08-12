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
                    Text("训练表现")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(ACETheme.ink)
                    Text("只汇总真实返回评分的报告；Cut 阶段评分会随解析覆盖度持续更新。")
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
                        insightStrip
                        reportList
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("训练表现")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var averageScore: Int {
        Int((reports.map(\.score).reduce(0, +) / Double(reports.count)).rounded())
    }

    private var scoreCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(.white.opacity(0.22), lineWidth: 11)
                Circle().trim(from: 0, to: CGFloat(min(averageScore, 100)) / 100)
                    .stroke(ACETheme.onPrimary, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) { Text("\(averageScore)").font(.title.bold()); Text("平均分").font(.caption2).opacity(0.72) }
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 5) {
                Text("综合表现").font(.headline)
                Text("已计入 \(reports.count) 份训练报告").font(.subheadline).opacity(0.78)
                Text("仅使用服务端返回的有效评分")
                    .font(.caption).opacity(0.7)
            }
            Spacer()
        }
        .foregroundStyle(ACETheme.onPrimary)
        .padding(20).background(ACETheme.heroGradient).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: ACETheme.green.opacity(0.18), radius: 16, y: 8)
    }

    private var reportList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已计入的训练报告").font(.headline).foregroundStyle(ACETheme.ink)
            ForEach(reports) { report in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.title).font(.subheadline.bold()).foregroundStyle(ACETheme.cardInk)
                        Text(report.summary).font(.caption).foregroundStyle(ACETheme.cardMuted).lineLimit(2)
                    }
                    Spacer()
                    Text("\(report.score)").font(.title3.bold()).foregroundStyle(ACETheme.green)
                }
                .padding(.vertical, 7)
                if report.id != reports.last?.id { Divider().overlay(ACETheme.cardLine) }
            }
        }
        .aceCard()
    }

    private var insightStrip: some View {
        HStack(spacing: 10) {
            insight("最高", "\(Int((reports.map(\.score).max() ?? 0).rounded()))", "arrow.up.right")
            insight("训练数", "\(reports.count)", "doc.text")
            insight("数据来源", "真实报告", "checkmark.seal")
        }
    }

    private func insight(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(ACETheme.green)
            Text(value).font(.subheadline.bold()).foregroundStyle(ACETheme.cardInk)
            Text(title).font(.caption2).foregroundStyle(ACETheme.cardMuted)
        }.frame(maxWidth: .infinity).padding(.vertical, 14).background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
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
                        guard let value = candidates.first?.value,
                              let match = value.range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression),
                              let score = Double(value[match]) else { return nil }
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
