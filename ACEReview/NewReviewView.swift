import Photos
import SwiftUI
import UserNotifications

struct NewReviewView: View {
    @ObservedObject var taskStore: TaskStore
    let onUploadSubmitted: () -> Void
    @EnvironmentObject private var uploads: UploadManager
    @State private var selectedAsset: PHAsset?
    @State private var title = ""
    @State private var player = ""
    @State private var notes = ""
    @State private var showPicker = false
    @State private var showPermissionExplanation = false
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if uploads.hasActiveUpload || uploads.snapshot.phase == .completed {
                        UploadStatusCard()
                    } else {
                        videoCard
                        detailsCard
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
        .alert("允许访问训练视频", isPresented: $showPermissionExplanation) {
            Button("继续") { requestPhotoAccess() }
            Button("暂不", role: .cancel) {}
        } message: {
            Text("ACE 只读取你选择的训练录像，用于后台上传和生成个人复盘报告。")
        }
        .task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        }
        .onChange(of: uploads.snapshot.phase) { _, phase in
            guard phase == .completed else { return }
            Task {
                await taskStore.load()
                try? await Task.sleep(for: .seconds(1.2))
                title = ""
                player = ""
                notes = ""
                selectedAsset = nil
                thumbnail = nil
                onUploadSubmitted()
            }
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
            Text("选择视频后会边读取边上传；已生成的分片可在后台继续传输。")
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
                    Button("重新选择") { showPermissionExplanation = true }
                }
                .font(.subheadline)
                .foregroundStyle(ACETheme.green)
            } else {
                Button("从相册选择") {
                    showPermissionExplanation = true
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

private struct UploadStatusCard: View {
    @EnvironmentObject private var uploads: UploadManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(ACETheme.lime)
                    Image(systemName: phaseIcon)
                        .foregroundStyle(ACETheme.ink)
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text(uploads.snapshot.phase.rawValue)
                        .font(.headline)
                    Text(uploads.snapshot.filename)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer()
            }
            HStack(spacing: 12) {
                ProgressView(value: progress)
                    .tint(ACETheme.lime)
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(ACETheme.lime)
                    .frame(width: 42, alignment: .trailing)
            }
            Text(uploads.snapshot.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            if uploads.snapshot.phase == .uploading
                || uploads.snapshot.phase == .finalizing {
                Label(
                     "已生成的分片可以在后台继续上传；读取视频时请尽量保持 ACE 打开",
                    systemImage: "checkmark.shield.fill"
                )
                .font(.footnote)
                .foregroundStyle(ACETheme.lime)
            }
            if uploads.snapshot.phase == .failed {
                Button("继续提交") { uploads.retryFailedParts() }
                    .foregroundStyle(ACETheme.lime)
                    .font(.headline)
            }
        }
        .padding(22)
        .foregroundStyle(.white)
        .background(ACETheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var progress: Double {
        switch uploads.snapshot.phase {
        case .idle:
            return 0
        case .reading:
            return 0.20
        case .uploading:
            let total = uploads.snapshot.totalBytes
            guard total > 0 else { return 0.20 }
            let actual = Double(uploads.snapshot.bytesUploaded) / Double(total)
            return min(1, max(0.20, actual))
        case .finalizing:
            return 0.98
        case .completed:
            return 1
        case .failed:
            let total = uploads.snapshot.totalBytes
            guard total > 0 else { return 0.20 }
            return min(1, max(
                0.20,
                Double(uploads.snapshot.bytesUploaded) / Double(total)
            ))
        }
    }

    private var phaseIcon: String {
        switch uploads.snapshot.phase {
        case .reading: "arrow.down.doc.fill"
        case .uploading: "arrow.up"
        case .finalizing: "sparkles"
        case .completed: "checkmark"
        case .failed: "exclamationmark"
        case .idle: "video"
        }
    }
}
