import Photos
import SwiftUI
import UserNotifications

struct NewReviewView: View {
    let onShowTasks: () -> Void
    @EnvironmentObject private var uploads: UploadManager
    @StateObject private var localEvidence = LocalEvidenceManager.shared
    @State private var selectedAsset: PHAsset?
    @State private var title = ""
    @State private var player = ""
    @State private var notes = ""
    @State private var showPicker = false
    @State private var thumbnail: UIImage?
    @State private var analysisMode = AnalysisMode.cloud
    @State private var entitlements: [EntitlementItem] = []
    @State private var isLoadingCredits = false
    @State private var creditLoadError = ""

    private enum AnalysisMode: String, CaseIterable, Identifiable {
        case cloud, local
        var id: String { rawValue }
        var title: String { self == .cloud ? "云端原视频" : "本地隐私" }
    }

    var body: some View {
        ZStack {
            ACEBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    creditDeck
                    if localEvidence.isWorking { localEvidenceCard }
                    if uploads.hasActiveUpload {
                        ActiveUploadEntryCard(onShowTasks: onShowTasks)
                    }
                    if uploads.canStartUpload {
                        modeChoices
                        detailsCard
                    } else {
                        Text("已有两个视频正在提交，请等待其中一个完成后继续。")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ACETheme.muted)
                            .aceCard()
                    }
                }
                .padding(18)
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPicker) {
            PhotoAssetPicker { asset in
                selectedAsset = asset
                loadThumbnail(asset)
            }
            .ignoresSafeArea()
        }
        .task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            localEvidence.resumePendingUpload()
            await refreshCredits()
        }
        .onAppear { Task { await refreshCredits() } }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    ACEBrandMark(size: 28)
                    Text("ACE 复盘")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(ACETheme.green)
                }
            Text("新建训练复盘")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(ACETheme.ink)
            Text("选择云端原视频，或仅提交设备端提取的关键动作画面。")
                .foregroundStyle(ACETheme.muted)
            }
            Spacer()
            Image(systemName: "bell")
                .font(.title3)
                .foregroundStyle(ACETheme.ink)
                .padding(10)
                .background(ACETheme.paper)
                .clipShape(Circle())
        }
        .padding(.top, 20)
    }

    private var creditDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("可用额度")
                .font(.headline)
                .foregroundStyle(ACETheme.ink)
            HStack(spacing: 12) {
                creditCell(title: "云端分析", value: cloudCredits, icon: "cloud")
                creditCell(title: "本地分析", value: localCredits, icon: "iphone")
            }
        }
        .aceCard()
    }

    private func creditCell(title: String, value: Int, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(ACETheme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(isLoadingCredits ? "--" : "\(value)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(ACETheme.ink)
                Text(title).font(.caption).foregroundStyle(ACETheme.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(14)
        .background(ACETheme.cream.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var modeChoices: some View {
        HStack(spacing: 12) {
            modeCard(
                mode: .cloud,
                title: "云端智能分析",
                detail: "完整视频与战术报告",
                icon: "cloud.sun"
            )
            modeCard(
                mode: .local,
                title: "本地隐私分析",
                detail: "原视频保留在设备",
                icon: "iphone"
            )
        }
    }

    private func modeCard(mode: AnalysisMode, title: String, detail: String, icon: String) -> some View {
        Button { analysisMode = mode } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(ACETheme.green)
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).multilineTextAlignment(.leading)
            }
            .foregroundStyle(ACETheme.ink)
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
            .padding(18)
            .background(ACETheme.paper)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(analysisMode == mode ? ACETheme.green : ACETheme.line, lineWidth: analysisMode == mode ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var videoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 205)
                    .frame(maxWidth: .infinity)
                    .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [ACETheme.green.opacity(0.13), ACETheme.lime.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    VStack(spacing: 13) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(ACETheme.green)
                        Text("选择训练视频")
                            .font(.headline)
                            .foregroundStyle(ACETheme.ink)
                        Text("支持 iPhone 相册中的 MOV、MP4 视频")
                            .font(.caption)
                            .foregroundStyle(ACETheme.muted)
                    }
                }
                .frame(height: 205)
            }

            if let selectedAsset {
                HStack {
                    Label(
                        durationText(selectedAsset.duration),
                        systemImage: "clock"
                    )
                    Spacer()
                    Button("重新选择") { beginVideoSelection() }
                }
                .font(.subheadline)
                .foregroundStyle(ACETheme.green)
            } else {
                Button("从相册选择") {
                    beginVideoSelection()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedAsset == nil ? "选择训练视频" : "补充训练信息")
                .font(.title3.bold())
                .foregroundStyle(ACETheme.ink)
            videoCard
            if selectedAsset != nil {
                creditSummary
                field("训练主题（选填）", text: $title)
                field("学员称呼（选填）", text: $player)
                VStack(alignment: .leading, spacing: 8) {
                    Text("想重点看看（选填）")
                        .font(.caption.bold())
                        .foregroundStyle(ACETheme.muted)
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            Button {
                guard let selectedAsset else { return }
                if analysisMode == .cloud {
                    uploads.begin(asset: selectedAsset, title: title, player: player, notes: notes)
                } else {
                    localEvidence.begin(asset: selectedAsset, title: title, player: player, notes: notes)
                }
                title = ""
                player = ""
                notes = ""
                self.selectedAsset = nil
                thumbnail = nil
                onShowTasks()
            } label: {
                PrimaryActionLabel(
                    title: analysisMode == .cloud ? "提交原视频并分析" : "设备端提取后分析",
                    systemImage: "arrow.up.circle.fill"
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedAsset == nil || localEvidence.isWorking || hasNoUsableCredits)
        }
        .aceCard()
    }

    private var creditSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(analysisMode == .cloud ? "云端分析额度" : "本地隐私分析额度")
                        .font(.caption.bold())
                        .foregroundStyle(ACETheme.muted)
                    if isLoadingCredits {
                        Text("正在读取可用次数")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ACETheme.ink)
                    } else if !creditLoadError.isEmpty {
                        Text("额度信息暂不可用，提交时将再次校验")
                            .font(.caption)
                            .foregroundStyle(ACETheme.muted)
                    } else {
                        Text("剩余 \(availableCredits) 次")
                            .font(.title3.bold())
                            .foregroundStyle(availableCredits > 0 ? ACETheme.green : .red)
                    }
                }
                Spacer()
                NavigationLink {
                    CommerceView()
                } label: {
                    Label("订购/加次", systemImage: "plus.circle")
                        .font(.caption.bold())
                }
                .foregroundStyle(ACETheme.green)
            }
            if hasNoUsableCredits {
                Text("当前模式没有可用次数，请先订购套餐或加次包。")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
    }

    private var availableCredits: Int {
        entitlements.reduce(0) { total, item in
            total + (analysisMode == .cloud ? item.cloudRemaining : item.localRemaining)
        }
    }

    private var cloudCredits: Int { entitlements.reduce(0) { $0 + $1.cloudRemaining } }
    private var localCredits: Int { entitlements.reduce(0) { $0 + $1.localRemaining } }

    private var hasNoUsableCredits: Bool {
        !isLoadingCredits && creditLoadError.isEmpty && availableCredits <= 0
    }

    private func refreshCredits() async {
        guard !isLoadingCredits else { return }
        isLoadingCredits = true
        defer { isLoadingCredits = false }
        do {
            let response = try await APIClient.shared.entitlements()
            entitlements = response.entitlements
            creditLoadError = ""
        } catch {
            creditLoadError = error.localizedDescription
        }
    }

    private var localEvidenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ProgressView().tint(ACETheme.lime)
                Text("本地隐私分析").font(.headline)
                Spacer()
                Text("\(Int(localEvidence.progress * 100))%")
                    .font(.caption.bold())
            }
            Text(localEvidence.message).font(.subheadline).foregroundStyle(.white.opacity(0.8))
            ProgressView(value: localEvidence.progress).tint(ACETheme.lime)
            if !localEvidence.errorMessage.isEmpty {
                Text(localEvidence.errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(18)
        .foregroundStyle(.white)
            .background(LinearGradient(colors: [ACETheme.ink, Color(red: 0.07, green: 0.20, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(ACETheme.muted)
            TextField("", text: text)
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 13))
        }
    }

    private func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    showPicker = true
                }
            }
        }
    }

    private func beginVideoSelection() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            showPicker = true
        } else {
            requestPhotoAccess()
        }
    }

    private func loadThumbnail(_ asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 900, height: 520),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async { thumbnail = image }
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct ActiveUploadEntryCard: View {
    @EnvironmentObject private var uploads: UploadManager
    let onShowTasks: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().fill(ACETheme.lime)
                    Image(systemName: "arrow.up")
                        .foregroundStyle(ACETheme.ink)
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(uploads.activeUploadCount) 个任务正在处理")
                        .font(.headline)
                    Text(uploads.activeFilenames.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer()
            }
            Text(
                uploads.canStartUpload
                    ? "你还可以继续提交一个视频"
                    : "已达到两个并行任务上限"
            )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Button(action: onShowTasks) {
                PrimaryActionLabel(
                    title: "查看当前任务",
                    systemImage: "rectangle.stack.fill"
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .tint(ACETheme.green)
        }
        .padding(22)
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [ACETheme.ink, Color(red: 0.07, green: 0.20, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
