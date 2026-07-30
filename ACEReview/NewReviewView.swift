import Photos
import SwiftUI
import UserNotifications

struct NewReviewView: View {
    let onShowTasks: () -> Void
    @EnvironmentObject private var uploads: UploadManager
    @State private var selectedAsset: PHAsset?
    @State private var title = ""
    @State private var player = ""
    @State private var notes = ""
    @State private var showPicker = false
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if uploads.hasActiveUpload {
                        ActiveUploadEntryCard(onShowTasks: onShowTasks)
                    }
                    if uploads.canStartUpload {
                        videoCard
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
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("NEW REVIEW")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.3)
                .foregroundStyle(ACETheme.green)
            Text("新建训练复盘")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(ACETheme.ink)
            Text("最多可同时提交两个视频；已生成的分片可在后台继续传输。")
                .foregroundStyle(ACETheme.muted)
        }
        .padding(.top, 20)
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
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(ACETheme.green.opacity(0.08))
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
        .aceCard()
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本次训练")
                .font(.title3.bold())
                .foregroundStyle(ACETheme.ink)
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
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            Button {
                guard let selectedAsset else { return }
                uploads.begin(
                    asset: selectedAsset,
                    title: title,
                    player: player,
                    notes: notes
                )
                title = ""
                player = ""
                notes = ""
                self.selectedAsset = nil
                thumbnail = nil
                onShowTasks()
            } label: {
                PrimaryActionLabel(
                    title: "提交并开始分析",
                    systemImage: "arrow.up.circle.fill"
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedAsset == nil)
        }
        .aceCard()
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
        .background(ACETheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
