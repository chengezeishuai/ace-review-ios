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
    @State private var athleteHandedness = ""
    @State private var athleteGoal = ""
    @State private var athleteProfiles = AthleteProfileStore.load()
    @State private var showAthleteChooser = false
    @State private var showAthleteProfiles = false
    @State private var displayedTaskID = ""
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
                    ACEPageHeader(
                        eyebrow: "ACE REVIEW",
                        title: "开始复盘",
                        subtitle: "上传训练视频，离开页面也会在后台继续。"
                    ) {
                        ACEBrandMark(size: 42)
                    }

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
                showPicker = false
                // Do not present the form while PHPicker is still dismissing;
                // otherwise iOS can place the new sheet behind the picker.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showDetails = true
                }
            }
        }
        .sheet(isPresented: $showDetails) {
            detailsSheet
        }
    }

    private var activeTaskID: String {
        if uploads.snapshot(for: displayedTaskID) != nil {
            return displayedTaskID
        }
        return uploads.orderedSnapshots.first?.id ?? ""
    }

    private var intelligenceCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("把训练变成下一次进步")
                        .font(.title3.bold())
                    Text("识别动作 · 校验证据 · 生成训练建议")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                Image(systemName: "figure.tennis")
                    .font(.system(size: 32, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
            HStack(spacing: 8) {
                heroTag("完整原片", icon: "film")
                heroTag("后台上传", icon: "arrow.up.circle")
                heroTag("证据优先", icon: "checkmark.seal")
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(ACETheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: ACETheme.green.opacity(0.18), radius: 18, y: 9)
    }

    private func heroTag(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.white.opacity(0.13), in: Capsule())
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
            .foregroundStyle(ACETheme.ink)
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(ACETheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ACETheme.line, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 10, y: 4)
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
            ZStack {
                ACEBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            ACEIconBadge(systemImage: "sparkles", size: 46)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("配置本次复盘").font(.title3.bold()).foregroundStyle(ACETheme.ink)
                                Text("只需确认三项，上传后可离开此页").font(.caption).foregroundStyle(ACETheme.muted)
                            }
                        }

                        sheetSection("1 · 视频信息", subtitle: "命名并告诉分析引擎你最关心什么") {
                            VStack(spacing: 0) {
                                TextField("复盘名称", text: $title).focused($focusedField, equals: .title).padding(16)
                                Divider().overlay(ACETheme.cardLine).padding(.leading, 16)
                                TextField("重点关注（选填）", text: $notes, axis: .vertical)
                                    .lineLimit(2...4).focused($focusedField, equals: .notes).padding(16)
                            }.foregroundStyle(ACETheme.cardInk).background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        sheetSection("2 · 运动员", subtitle: "性别、水平、惯用手和目标会参与综合判断") {
                            ACEGroupCard {
                                VStack(spacing: 0) {
                                    Button { dismissKeyboard(); showAthleteChooser = true } label: {
                                        HStack(spacing: 12) {
                                            ACEIconBadge(systemImage: "figure.tennis", size: 38)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(player.isEmpty ? "选择运动员" : player).font(.subheadline.weight(.semibold)).foregroundStyle(ACETheme.cardInk)
                                                Text(player.isEmpty ? "可跳过，仍可进行通用分析" : athleteSummary).font(.caption).foregroundStyle(ACETheme.cardMuted).lineLimit(2)
                                            }
                                            Spacer(); Image(systemName: "chevron.up.chevron.down").font(.caption.bold()).foregroundStyle(ACETheme.green)
                                        }.padding(15)
                                    }.buttonStyle(.plain)
                                    Divider().overlay(ACETheme.cardLine).padding(.leading, 66)
                                    Button { dismissKeyboard(); DispatchQueue.main.async { showAthleteProfiles = true } } label: {
                                        ACESettingsRow(icon: "person.crop.circle.badge.plus", title: "新建或管理运动员资料", subtitle: "完善个人情况，让建议更贴合")
                                    }.buttonStyle(.plain)
                                }
                            }
                        }

                        sheetSection("3 · 分析方式", subtitle: "根据观看习惯选择，后续仍可继续深入") {
                            HStack(spacing: 10) {
                                scopeOption("完整报告", "直接完成全量逐拍分析", "doc.text.magnifyingglass", value: "full_report")
                                scopeOption("先看 Cut", "先整理回合，再按需深入", "scissors", value: "cuts_only")
                            }
                            Text(analysisScope == "cuts_only" ? "先快速生成可回看的训练回合；解析任一 Cut 后即有阶段评分，解析更多后自动更新。" : "直接生成完整逐拍报告；完成前只展示总进度，不提前显示分片。")
                                .font(.caption).foregroundStyle(ACETheme.muted).padding(.horizontal, 2)
                        }

                        Button(action: submitReview) {
                            PrimaryActionLabel(title: isSubmitting ? "正在创建任务" : "开始云端分析", systemImage: "arrow.up.circle.fill", isWorking: isSubmitting)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(selectedAsset == nil || !uploads.canStartUpload || isSubmitting || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Text("视频将安全上传；多段视频串行上传，上传完成后云端可并行分析。")
                            .font(.caption2).foregroundStyle(ACETheme.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    }
                    .padding(18).padding(.bottom, 24)
                }
            }
            .navigationTitle("提交复盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { showDetails = false } } }
            .scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { focusedField = nil } } }
            .alert("提交未完成", isPresented: Binding(get: { !uploadError.isEmpty }, set: { if !$0 { uploadError = "" } })) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(uploadError)
            }
            .sheet(isPresented: $showAthleteProfiles) {
                AthleteProfilesSheet(profiles: $athleteProfiles) { profile in
                    player = profile.name
                    athleteGender = profile.gender
                    athleteLevel = profile.level
                    athleteHandedness = profile.dominantHand ?? ""
                    athleteGoal = profile.trainingGoal ?? ""
                }
            }
            .sheet(isPresented: $showAthleteChooser) {
                AthleteChooserSheet(profiles: athleteProfiles, selectedName: player, onSelect: { profile in
                    if let profile { selectAthlete(profile) } else { clearAthlete() }
                }, onManage: {
                    showAthleteChooser = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showAthleteProfiles = true }
                })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .tint(ACETheme.green)
        }
    }

    private func sheetSection<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(ACETheme.ink)
            Text(subtitle).font(.caption).foregroundStyle(ACETheme.muted)
            content()
        }
    }

    private func scopeOption(_ title: String, _ subtitle: String, _ icon: String, value: String) -> some View {
        Button { analysisScope = value } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack { Image(systemName: icon).foregroundStyle(analysisScope == value ? ACETheme.onPrimary : ACETheme.green); Spacer(); Image(systemName: analysisScope == value ? "checkmark.circle.fill" : "circle").foregroundStyle(analysisScope == value ? ACETheme.onPrimary : ACETheme.cardMuted) }
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption2).opacity(0.72).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(analysisScope == value ? ACETheme.onPrimary : ACETheme.cardInk)
            .padding(15).frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
            .background(analysisScope == value ? ACETheme.green : ACETheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(.plain)
    }

    private var athleteSummary: String { [athleteGender, athleteLevel, athleteHandedness, athleteGoal].filter { !$0.isEmpty }.joined(separator: " · ") }
    private func clearAthlete() { player = ""; athleteGender = ""; athleteLevel = ""; athleteHandedness = ""; athleteGoal = "" }
    private func selectAthlete(_ profile: AthleteProfile) { player = profile.name; athleteGender = profile.gender; athleteLevel = profile.level; athleteHandedness = profile.dominantHand ?? ""; athleteGoal = profile.trainingGoal ?? "" }

    private func submitReview() {
        guard let asset = selectedAsset else { return }
        isSubmitting = true; uploadError = ""
        uploads.begin(asset: asset, title: title, player: player, notes: composedNotes, analysisScope: analysisScope, athleteGender: athleteGender, athleteLevel: athleteLevel, athleteHandedness: athleteHandedness, athleteGoal: athleteGoal, onTaskCreated: { taskID in
            displayedTaskID = taskID; isSubmitting = false; showDetails = false; selectedAsset = nil; title = ""; clearAthlete(); notes = ""; analysisScope = "full_report"; onSubmitted()
        }, onFailure: { message in isSubmitting = false; uploadError = message })
    }

    private func progress(for snapshot: UploadSnapshot) -> Double {
        if snapshot.totalBytes > 0 {
            let value = Double(snapshot.bytesUploaded) / Double(snapshot.totalBytes) * 100
            return snapshot.phase == .failed ? min(99, value) : value
        }
        return Double(snapshot.preparationPercent)
    }

    private func defaultTitle(for asset: PHAsset) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日训练"
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
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum DetailField: Hashable { case title, notes }
struct AthleteProfile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var gender: String
    var level: String
    var dominantHand: String?
    var trainingGoal: String?
}

enum AthleteProfileStore {
    static let key = "ace.athlete.profiles"
    static func load() -> [AthleteProfile] { guard let data = UserDefaults.standard.data(forKey: key), let value = try? JSONDecoder().decode([AthleteProfile].self, from: data) else { return [] }; return value }
    static func save(_ value: [AthleteProfile]) { UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key) }
}

struct AthleteChooserSheet: View {
    let profiles: [AthleteProfile]
    let selectedName: String
    let onSelect: (AthleteProfile?) -> Void
    let onManage: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ACEBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("这次分析谁？").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(ACETheme.ink)
                            Text("选择后会结合其基础情况生成建议，也可以暂不指定。")
                                .font(.subheadline).foregroundStyle(ACETheme.muted)
                        }

                        athleteOption(name: "暂不指定", detail: "使用通用运动分析标准", icon: "person.crop.circle.dashed", isSelected: selectedName.isEmpty) {
                            onSelect(nil); dismiss()
                        }
                        ForEach(profiles) { profile in
                            athleteOption(name: profile.name, detail: profileSummary(profile), icon: "figure.tennis", isSelected: selectedName == profile.name) {
                                onSelect(profile); dismiss()
                            }
                        }
                        if profiles.isEmpty {
                            VStack(spacing: 9) {
                                Image(systemName: "person.2.slash").font(.title2).foregroundStyle(ACETheme.green)
                                Text("还没有运动员资料").font(.subheadline.bold()).foregroundStyle(ACETheme.cardInk)
                                Text("可暂不指定，或先创建一份资料。做一次，之后可重复选择。")
                                    .font(.caption).foregroundStyle(ACETheme.cardMuted).multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity).aceCard()
                        }
                        Button(action: onManage) {
                            Label(profiles.isEmpty ? "创建运动员资料" : "管理运动员资料", systemImage: "person.crop.circle.badge.plus")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(PrimaryButtonStyle())
                    }.padding(18).padding(.bottom, 20)
                }
            }
            .navigationTitle("选择运动员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.foregroundStyle(ACETheme.green) } }
        }
    }

    private func athleteOption(name: String, detail: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ACEIconBadge(systemImage: icon, color: isSelected ? ACETheme.onPrimary : ACETheme.green, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.headline)
                    Text(detail).font(.caption).opacity(0.7).lineLimit(2)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(isSelected ? ACETheme.onPrimary : ACETheme.cardMuted)
            }
            .foregroundStyle(isSelected ? ACETheme.onPrimary : ACETheme.cardInk)
            .padding(15)
            .background(isSelected ? ACETheme.green : ACETheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isSelected ? .clear : ACETheme.cardLine, lineWidth: 1) }
        }.buttonStyle(.plain)
    }

    private func profileSummary(_ profile: AthleteProfile) -> String {
        let value = [profile.gender, profile.level, profile.dominantHand ?? "", profile.trainingGoal ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
        return value.isEmpty ? "尚未填写详细资料" : value
    }
}

struct AthleteProfilesSheet: View {
    @Binding var profiles: [AthleteProfile]
    let onSelect: (AthleteProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var gender = ""
    @State private var level = ""
    @State private var dominantHand = ""
    @State private var trainingGoal = ""
    var body: some View {
        NavigationStack {
            ZStack {
                ACEBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("已保存资料").font(.headline).foregroundStyle(ACETheme.ink)
                        if profiles.isEmpty {
                            Text("还没有资料，新建后会保存在本机。")
                                .font(.subheadline).foregroundStyle(ACETheme.muted).aceCard()
                        } else {
                            ForEach(profiles) { profile in
                                HStack(spacing: 12) {
                                    ACEIconBadge(systemImage: "figure.tennis", size: 42)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(profile.name).font(.headline).foregroundStyle(ACETheme.cardInk)
                                        Text(profileSummary(profile)).font(.caption).foregroundStyle(ACETheme.cardMuted).lineLimit(2)
                                    }
                                    Spacer()
                                    Button(role: .destructive) { remove(profile) } label: { Image(systemName: "trash").foregroundStyle(ACETheme.danger).padding(8) }
                                }.aceCard()
                                .onTapGesture { onSelect(profile); dismiss() }
                            }
                        }

                        Text("新建运动员").font(.headline).foregroundStyle(ACETheme.ink)
                        VStack(alignment: .leading, spacing: 15) {
                            TextField("姓名或昵称", text: $name)
                                .padding(14).background(ACETheme.cardInk.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 13))
                            choiceGroup("性别", values: ["女", "男", "其他"], selection: $gender)
                            choiceGroup("基础水平", values: ["初学", "业余进阶", "比赛训练"], selection: $level)
                            choiceGroup("惯用手", values: ["右手", "左手"], selection: $dominantHand)
                            TextField("训练目标（例如：提升反手稳定性）", text: $trainingGoal, axis: .vertical)
                                .lineLimit(2...3).padding(14).background(ACETheme.cardInk.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 13))
                            Button("保存运动员资料", action: saveProfile).buttonStyle(PrimaryButtonStyle())
                                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }.aceCard().foregroundStyle(ACETheme.cardInk)
                    }.padding(18).padding(.bottom, 30)
                }
            }
            .navigationTitle("运动员资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() }.foregroundStyle(ACETheme.green) } }
        }
    }

    private func choiceGroup(_ title: String, values: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(ACETheme.cardMuted)
            FlowLayout(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button(value) { selection.wrappedValue = selection.wrappedValue == value ? "" : value }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selection.wrappedValue == value ? ACETheme.onPrimary : ACETheme.cardInk)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(selection.wrappedValue == value ? ACETheme.green : ACETheme.cardInk.opacity(0.06), in: Capsule())
                }
            }
        }
    }
    private func saveProfile() {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let cleanedGoal = String(trainingGoal.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        let profile = AthleteProfile(name: cleaned, gender: gender, level: level, dominantHand: dominantHand.isEmpty ? nil : dominantHand, trainingGoal: cleanedGoal.isEmpty ? nil : cleanedGoal)
        profiles.append(profile); AthleteProfileStore.save(profiles); onSelect(profile)
        name = ""; gender = ""; level = ""; dominantHand = ""; trainingGoal = ""; dismiss()
    }
    private func remove(_ profile: AthleteProfile) { profiles.removeAll { $0.id == profile.id }; AthleteProfileStore.save(profiles) }
    private func profileSummary(_ profile: AthleteProfile) -> String { [profile.gender, profile.level, profile.dominantHand ?? "", profile.trainingGoal ?? ""].filter { !$0.isEmpty }.joined(separator: " · ") }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    init(spacing: CGFloat, @ViewBuilder content: () -> Content) { self.spacing = spacing; self.content = content() }
    var body: some View { HStack(spacing: spacing) { content } }
}
