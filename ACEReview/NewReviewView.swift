import Photos
import SwiftUI

struct NewReviewView: View {
    @EnvironmentObject private var uploads: UploadManager
    @State private var selectedAsset: PHAsset?
    @State private var showPicker = false
    @State private var showDetails = false
    @State private var title = ""
    @State private var player = ""
    @State private var notes = ""
    @State private var analysisScope = "full_report"
    @State private var isSubmitting = false
    @State private var uploadError = ""
    let onSubmitted: () -> Void

    init(onSubmitted: @escaping () -> Void = {}) {
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        ZStack {
            ACETheme.cream.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    brandHeader
                    Text("新建复盘")
                        .font(.system(size: 33, weight: .bold, design: .rounded))
                        .foregroundStyle(ACETheme.ink)
                    Text("上传一段训练视频，获得清晰、可信的技术复盘。")
                        .font(.subheadline)
                        .foregroundStyle(ACETheme.muted)

                    intelligenceCard
                    chooseVideoButton

                    if let selectedAsset {
                        selectedVideo(selectedAsset)
                    }
                    if let snapshot = uploads.snapshot(for: activeTaskID), snapshot.phase != .idle {
                        uploadStatus(snapshot)
                    }
                    if !uploads.lastError.isEmpty {
                        Label(uploads.lastError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ACETheme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
        }
        .sheet(isPresented: $showPicker) {
            PhotoAssetPicker { asset in
                selectedAsset = asset
                title = defaultTitle(for: asset)
                showDetails = true
            }
        }
        .sheet(isPresented: $showDetails) {
            detailsSheet
        }
    }

    private var activeTaskID: String {
        uploads.snapshots.keys.first ?? ""
    }

    private var brandHeader: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                ACEBrandMark(size: 29)
                Text("ACE Review")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(ACETheme.green)
            }
            Spacer()
            Image(systemName: "bell")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ACETheme.ink)
        }
        .frame(height: 38)
    }

    private var intelligenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(ACETheme.green)
                    .frame(width: 48, height: 48)
                    .background(ACETheme.green.opacity(0.09))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("云端智能分析")
                        .font(.headline)
                        .foregroundStyle(ACETheme.ink)
                    Text("逐拍识别、证据校验、训练建议")
                        .font(.caption)
                        .foregroundStyle(ACETheme.muted)
                }
            }
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(ACETheme.green)
                Text("仅基于清晰可见的动作给出结论")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ACETheme.green)
            }
        }
        .padding(17)
        .background(ACETheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ACETheme.line, lineWidth: 1) }
    }

    private var chooseVideoButton: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 19, weight: .semibold))
                Text(selectedAsset == nil ? "选择视频" : "更换视频")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 54)
            .background(ACETheme.green)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func selectedVideo(_ asset: PHAsset) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "video.fill")
                .font(.title3)
                .foregroundStyle(ACETheme.green)
                .frame(width: 46, height: 46)
                .background(ACETheme.green.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title.isEmpty ? "训练视频" : title)
                    .font(.subheadline.bold())
                    .foregroundStyle(ACETheme.ink)
                    .lineLimit(1)
                Text(durationText(asset.duration))
                    .font(.caption)
                    .foregroundStyle(ACETheme.muted)
            }
            Spacer()
            Button("提交") { showDetails = true }
                .font(.caption.bold())
                .foregroundStyle(ACETheme.green)
        }
        .padding(14)
        .background(ACETheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ACETheme.line, lineWidth: 1) }
    }

    private func uploadStatus(_ snapshot: UploadSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(uploadTitle(snapshot)).font(.headline).foregroundStyle(ACETheme.ink)
                    Text(snapshot.message).font(.caption).foregroundStyle(ACETheme.muted)
                }
                Spacer()
                Text("\(Int(progress(for: snapshot).rounded()))%")
                    .font(.caption.bold())
                    .foregroundStyle(ACETheme.green)
            }
            ProgressView(value: progress(for: snapshot), total: 100).tint(ACETheme.green)
            HStack(spacing: 0) {
                uploadStep("读取资源", active: snapshot.phase == .reading, complete: snapshot.phase != .reading)
                uploadStep("上传视频", active: snapshot.phase == .uploading, complete: snapshot.phase == .finalizing || snapshot.phase == .completed)
                uploadStep("启动分析", active: snapshot.phase == .finalizing, complete: snapshot.phase == .completed)
            }
        }
        .padding(18)
        .background(ACETheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ACETheme.line, lineWidth: 1) }
    }

    private func uploadStep(_ title: String, active: Bool, complete: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: complete ? "checkmark.circle.fill" : active ? "arrow.triangle.2.circlepath.circle.fill" : "circle")
                .foregroundStyle(complete || active ? ACETheme.green : ACETheme.line)
                .symbolEffect(.pulse, options: .repeating, isActive: active)
            Text(title).font(.caption2).foregroundStyle(active || complete ? ACETheme.ink : ACETheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func uploadTitle(_ snapshot: UploadSnapshot) -> String {
        switch snapshot.phase {
        case .reading: return "正在准备上传资源"
        case .uploading: return "正在安全上传视频"
        case .finalizing: return "正在创建分析任务"
        case .completed: return "云端分析已开始"
        default: return snapshot.phase.rawValue
        }
    }

    private var detailsSheet: some View {
        NavigationStack {
            Form {
                Section("视频信息") {
                    TextField("复盘名称", text: $title)
                    TextField("运动员（选填）", text: $player)
                    TextField("想重点查看什么（选填）", text: $notes, axis: .vertical)
                }
                Section {
                    Picker("分析范围", selection: $analysisScope) {
                        Text("完整报告").tag("full_report")
                        Text("仅生成 Cut").tag("cuts_only")
                    }
                    .pickerStyle(.segmented)
                    Text(analysisScope == "cuts_only" ? "适合长视频：生成可回看的训练片段，不展开逐拍报告。" : "生成完整逐拍报告，并同时提供 Cut 回看。")
                        .font(.caption).foregroundStyle(ACETheme.muted)
                }
                Section {
                    Button(action: {
                        guard let asset = selectedAsset else { return }
                        isSubmitting = true
                        uploadError = ""
                        uploads.begin(
                            asset: asset,
                            title: title,
                            player: player,
                            notes: notes,
                            analysisScope: analysisScope,
                            onTaskCreated: { _ in
                                isSubmitting = false
                                showDetails = false
                                selectedAsset = nil
                                title = ""
                                player = ""
                                notes = ""
                                analysisScope = "full_report"
                                onSubmitted()
                            },
                            onFailure: { message in
                                isSubmitting = false
                                uploadError = message
                            }
                        )
                    }) {
                        Text(isSubmitting ? "正在创建任务..." : "开始云端分析")
                    }
                    .overlay { if isSubmitting { ProgressView().tint(ACETheme.green) } }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(ACETheme.green)
                    .disabled(selectedAsset == nil || !uploads.canStartUpload || isSubmitting)
                }
            }
            .navigationTitle("提交复盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { showDetails = false } } }
            .alert("提交未完成", isPresented: Binding(get: { !uploadError.isEmpty }, set: { if !$0 { uploadError = "" } })) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(uploadError)
            }
        }
    }

    private func progress(for snapshot: UploadSnapshot) -> Double {
        if snapshot.totalBytes > 0 {
            let value = Double(snapshot.bytesUploaded) / Double(snapshot.totalBytes) * 100
            return snapshot.phase == .failed ? min(99, value) : value
        }
        return Double(snapshot.preparationPercent)
    }

    private func defaultTitle(for asset: PHAsset) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "MMM d 训练"
        return formatter.string(from: asset.creationDate ?? Date())
    }

    private func durationText(_ value: TimeInterval) -> String {
        String(format: "%d:%02d", Int(value) / 60, Int(value) % 60)
    }
}
