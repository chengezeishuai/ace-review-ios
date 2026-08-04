import SwiftUI

struct ThemePaletteView: View {
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("球场配色").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(ACEPalette.presets) { palette in
                        Button { theme.selectedID = palette.id } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 0) {
                                    Color(aceHex: palette.primary)
                                    Color(aceHex: palette.accent)
                                }
                                .frame(height: 68)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                HStack {
                                    Text(palette.name).font(.subheadline.bold()).foregroundStyle(ACETheme.ink)
                                    Spacer()
                                    if theme.selectedID == palette.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(aceHex: palette.primary)) }
                                }
                            }
                            .padding(12)
                            .background(Color(aceHex: palette.card))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 18).stroke(theme.selectedID == palette.id ? Color(aceHex: palette.primary) : Color.black.opacity(0.08), lineWidth: theme.selectedID == palette.id ? 2 : 1) }
                        }.buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("自定义调色盘").font(.headline); Spacer(); if theme.selectedID == "custom" { Image(systemName: "checkmark.circle.fill").foregroundStyle(ACETheme.green) } }
                    colorPicker("主题色", value: $theme.customPrimary)
                    colorPicker("强调色", value: $theme.customAccent)
                    colorPicker("页面背景", value: $theme.customBackground)
                    colorPicker("卡片背景", value: $theme.customCard)
                    Button("应用自定义配色") { theme.applyCustom() }
                        .buttonStyle(PrimaryButtonStyle())
                }.aceCard()
            }.padding(18)
        }
        .background(ACETheme.cream.ignoresSafeArea())
        .navigationTitle("主题配色")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorPicker(_ title: String, value: Binding<String>) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(aceHex: value.wrappedValue) }, set: { value.wrappedValue = $0.aceHex }), supportsOpacity: false)
    }
}

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
