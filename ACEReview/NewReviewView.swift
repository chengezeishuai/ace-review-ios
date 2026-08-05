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
    @State private var athleteGender = ""
    @State private var athleteLevel = ""
    @State private var athleteProfiles = AthleteProfileStore.load()
    @State private var showAthleteProfiles = false
    @FocusState private var focusedField: DetailField?
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
        .sheet(isPresented: $showAthleteProfiles) {
            AthleteProfilesSheet(profiles: $athleteProfiles) { profile in
                player = profile.name
                athleteGender = profile.gender
                athleteLevel = profile.level
            }
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
                    TextField("复盘名称", text: $title).focused($focusedField, equals: .title)
                    TextField("想重点查看什么（选填）", text: $notes, axis: .vertical)
                        .focused($focusedField, equals: .notes)
                        .submitLabel(.done)
                        .onSubmit { dismissKeyboard() }
                }
                Section("运动员信息（可选）") {
                    Text("选择运动员后，系统会结合其性别和基础水平给出更贴合的分析建议。")
                        .font(.caption).foregroundStyle(ACETheme.muted)
                    HStack {
                        Text("选择运动员").font(.subheadline)
                        Spacer()
                        Menu {
                            Button("未选择") { player = ""; athleteGender = ""; athleteLevel = "" }
                            ForEach(athleteProfiles) { profile in
                                Button(profile.name) { player = profile.name; athleteGender = profile.gender; athleteLevel = profile.level }
                            }
                            Divider()
                        } label: {
                            Text(player.isEmpty ? "选择运动员" : player).foregroundStyle(ACETheme.green)
                        }
                    }
                    Button { dismissKeyboard(); DispatchQueue.main.async { showAthleteProfiles = true } } label: {
                        Label("新建或管理运动员资料", systemImage: "person.crop.circle.badge.plus")
                    }
                    .font(.subheadline.weight(.semibold))
                    if !athleteGender.isEmpty || !athleteLevel.isEmpty {
                        Text([athleteGender, athleteLevel].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(ACETheme.muted)
                    }
                }
                Section {
                    Picker("分析范围", selection: $analysisScope) {
                        Text("完整报告").tag("full_report")
                        Text("先生成 Cut").tag("cuts_only")
                    }
                    .pickerStyle(.segmented)
                    Text(analysisScope == "cuts_only" ? "适合长视频：先快速生成可回看的训练片段，之后可按需选择片段生成逐拍报告。" : "生成完整逐拍报告，并同时提供 Cut 回看。")
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
                            notes: composedNotes,
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
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { focusedField = nil } } }
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

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var composedNotes: String {
        let profile = [athleteGender.isEmpty ? nil : "性别：\(athleteGender)", athleteLevel.isEmpty ? nil : "基础：\(athleteLevel)"]
            .compactMap { $0 }.joined(separator: "，")
        return profile.isEmpty ? notes : (notes.isEmpty ? "运动员信息：\(profile)" : "运动员信息：\(profile)\n\(notes)")
    }
}

private enum DetailField: Hashable { case title, notes }
struct AthleteProfile: Codable, Identifiable { var id = UUID(); var name: String; var gender: String; var level: String }

enum AthleteProfileStore {
    static let key = "ace.athlete.profiles"
    static func load() -> [AthleteProfile] { guard let data = UserDefaults.standard.data(forKey: key), let value = try? JSONDecoder().decode([AthleteProfile].self, from: data) else { return [] }; return value }
    static func save(_ value: [AthleteProfile]) { UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key) }
}
struct AthleteProfilesSheet: View {
    @Binding var profiles: [AthleteProfile]
    let onSelect: (AthleteProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var gender = ""
    @State private var level = ""
    var body: some View {
        NavigationStack {
            List {
                Section("已保存资料") {
                    ForEach(profiles) { profile in
                        Button { onSelect(profile); dismiss() } label: { VStack(alignment: .leading) { Text(profile.name); Text([profile.gender, profile.level].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) } }
                    }.onDelete { profiles.remove(atOffsets: $0); AthleteProfileStore.save(profiles) }
                }
                Section("新建运动员") {
                    TextField("姓名或昵称", text: $name)
                    Picker("性别", selection: $gender) {
                        Text("未选择").tag("")
                        Text("女").tag("女")
                        Text("男").tag("男")
                        Text("其他").tag("其他")
                    }
                    Picker("基础", selection: $level) {
                        Text("未选择").tag("")
                        Text("初学").tag("初学")
                        Text("业余进阶").tag("业余进阶")
                        Text("比赛训练").tag("比赛训练")
                    }
                    Button("保存") { guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; profiles.append(AthleteProfile(name: name, gender: gender, level: level)); AthleteProfileStore.save(profiles); name = ""; gender = ""; level = "" }
                }
            }.navigationTitle("运动员资料").toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
        }
    }
}
