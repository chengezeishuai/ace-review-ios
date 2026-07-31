import SwiftUI

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
