import Photos
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

struct PhotoBackupSettingsView: View {
    @AppStorage("ace.mediaBackupEnabled") private var backupEnabled = false
    @State private var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var showConsent = false

    var body: some View {
        Form {
            Section("媒体备份") {
                Toggle("启用照片与视频备份", isOn: Binding(
                    get: { backupEnabled },
                    set: { enabled in
                        if enabled { showConsent = true } else { backupEnabled = false }
                    }
                ))
                Text(statusText).font(.footnote).foregroundStyle(ACETheme.muted)
            }
            Section("隐私说明") {
                Text("备份必须由你明确开启。系统照片权限只用于读取你授权的媒体，应用不会因为取得权限而自动上传全部照片或视频。")
                    .font(.footnote)
            }
        }
        .navigationTitle("隐私与数据")
        .navigationBarTitleDisplayMode(.inline)
        .alert("启用媒体备份？", isPresented: $showConsent) {
            Button("继续", role: .none) { requestAuthorization() }
            Button("取消", role: .cancel) { backupEnabled = false }
        } message: {
            Text("启用后，应用只会按你确认的范围与网络策略同步媒体。你可随时在此页面关闭。")
        }
        .onAppear { authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite) }
    }

    private var statusText: String {
        switch authorization {
        case .authorized, .limited: return backupEnabled ? "已启用，等待选择同步范围。" : "相册已授权，尚未启用备份。"
        case .denied, .restricted: return "相册访问未授权，请在系统设置中开启。"
        default: return "启用后将请求系统照片权限。"
        }
    }

    private func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                authorization = status
                backupEnabled = status == .authorized || status == .limited
            }
        }
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
