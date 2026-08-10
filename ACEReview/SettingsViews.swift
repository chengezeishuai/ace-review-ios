import SwiftUI

private struct SettingsScreen<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ZStack {
            ACEBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(ACETheme.ink)
                    Text(subtitle).font(.subheadline).foregroundStyle(ACETheme.muted).fixedSize(horizontal: false, vertical: true)
                    content
                }
                .padding(18).padding(.bottom, 28)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsLabel: View {
    let title: String
    var body: some View { Text(title).font(.caption.weight(.bold)).tracking(0.7).foregroundStyle(ACETheme.muted).padding(.leading, 4) }
}

struct ThemePaletteView: View {
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        SettingsScreen(title: "主题配色", subtitle: "整套界面和新生成的报告都会跟随你的调色盘，文字对比度会自动适配。") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ACEPalette.presets) { palette in
                    Button { theme.selectedID = palette.id } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 0) { Color(aceHex: palette.primary); Color(aceHex: palette.accent) }
                                .frame(height: 68).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            HStack {
                                Text(palette.name).font(.subheadline.bold()).foregroundStyle(Color(aceHex: palette.card).aceHex == "000000" ? .white : Color(aceHex: "142018"))
                                Spacer()
                                if theme.selectedID == palette.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(aceHex: palette.primary)) }
                            }
                        }
                        .padding(12).background(Color(aceHex: palette.card))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 18).stroke(theme.selectedID == palette.id ? Color(aceHex: palette.primary) : Color.black.opacity(0.08), lineWidth: theme.selectedID == palette.id ? 2 : 1) }
                    }.buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("自由调色盘").font(.headline).foregroundStyle(ACETheme.cardInk); Spacer(); if theme.selectedID == "custom" { Image(systemName: "checkmark.circle.fill").foregroundStyle(ACETheme.green) } }
                colorPicker("主题色", value: $theme.customPrimary)
                colorPicker("强调色", value: $theme.customAccent)
                colorPicker("页面背景", value: $theme.customBackground)
                colorPicker("卡片背景", value: $theme.customCard)
                Button("应用自定义配色") { theme.applyCustom() }.buttonStyle(PrimaryButtonStyle())
            }.aceCard().foregroundStyle(ACETheme.cardInk)
        }
    }

    private func colorPicker(_ title: String, value: Binding<String>) -> some View {
        ColorPicker(title, selection: Binding(get: { Color(aceHex: value.wrappedValue) }, set: { value.wrappedValue = $0.aceHex }), supportsOpacity: false)
    }
}

struct ProfileDetailsView: View {
    let username: String
    var body: some View {
        SettingsScreen(title: "个人资料", subtitle: "用于识别账号归属；运动员资料在提交复盘时单独管理。") {
            ACEGroupCard {
                VStack(spacing: 0) {
                    ACESettingsRow(icon: "person.fill", title: "用户名", subtitle: username.isEmpty ? "ACE 用户" : username) { EmptyView() }
                    Divider().overlay(ACETheme.cardLine).padding(.leading, 66)
                    ACESettingsRow(icon: "checkmark.seal.fill", title: "产品", subtitle: "ACE Review 网球训练复盘") { EmptyView() }
                }
            }
            infoPanel(icon: "lock.shield", title: "资料隔离", text: "训练记录、视频和报告仅在账号与所属组织授权范围内显示。")
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("ace.settings.compactLibrary") private var compactLibrary = false

    var body: some View {
        SettingsScreen(title: "设置", subtitle: "管理任务列表和视觉偏好；所有可操作项都会立即生效。") {
            SettingsLabel(title: "任务库")
            ACEGroupCard {
                VStack(spacing: 0) {
                    toggleRow(icon: "rectangle.compress.vertical", title: "紧凑任务列表", subtitle: "减少卡片留白，一屏展示更多任务", value: $compactLibrary)
                }
            }
            SettingsLabel(title: "外观与文档")
            ACEGroupCard {
                VStack(spacing: 0) {
                    NavigationLink { ThemePaletteView() } label: { ACESettingsRow(icon: "paintpalette.fill", title: "主题配色", subtitle: "当前配色会应用到所有页面") }.buttonStyle(.plain)
                    Divider().overlay(ACETheme.cardLine).padding(.leading, 66)
                    NavigationLink { PrivacyCenterView() } label: { ACESettingsRow(icon: "hand.raised.fill", title: "隐私与数据") }.buttonStyle(.plain)
                }
            }
            Text("ACE Review · 版本 \(appVersion)").font(.caption).foregroundStyle(ACETheme.muted).frame(maxWidth: .infinity)
        }
    }

    private func toggleRow(icon: String, title: String, subtitle: String, value: Binding<Bool>) -> some View {
        ACESettingsRow(icon: icon, title: title, subtitle: subtitle) { Toggle("", isOn: value).labelsHidden().tint(ACETheme.green) }
    }
    private var appVersion: String { "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))" }
}

struct AccountSecurityView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var showLogout = false

    var body: some View {
        SettingsScreen(title: "账号安全", subtitle: "登录凭证存入 iOS 钥匙串，传输使用加密连接。") {
            securityHero
            SettingsLabel(title: "安全操作")
            ACEGroupCard {
                VStack(spacing: 0) {
                    NavigationLink { ChangePasswordView() } label: { ACESettingsRow(icon: "key.fill", title: "修改登录密码", subtitle: "建议使用 8 位以上且不重复的密码") }.buttonStyle(.plain)
                    Divider().overlay(ACETheme.cardLine).padding(.leading, 66)
                    Button { showLogout = true } label: { ACESettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "退出当前设备", subtitle: "清除本机登录凭证", tint: ACETheme.warning) { Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(ACETheme.cardMuted) } }.buttonStyle(.plain)
                }
            }
            SettingsLabel(title: "账号注销")
            NavigationLink { AccountDeletionInformationView() } label: {
                HStack(spacing: 13) {
                    ACEIconBadge(systemImage: "person.crop.circle.badge.minus", color: ACETheme.danger)
                    VStack(alignment: .leading, spacing: 3) { Text("注销账号与删除数据").font(.subheadline.weight(.semibold)); Text("查看影响、保留规则和申请方式").font(.caption).foregroundStyle(ACETheme.cardMuted) }
                    Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(ACETheme.cardMuted)
                }.foregroundStyle(ACETheme.cardInk).aceCard()
            }.buttonStyle(.plain)
        }
        .alert("退出当前设备？", isPresented: $showLogout) {
            Button("退出", role: .destructive) { session.logout() }; Button("取消", role: .cancel) {}
        }
    }

    private var securityHero: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill").font(.system(size: 32)).foregroundStyle(ACETheme.onPrimary)
            VStack(alignment: .leading, spacing: 4) { Text("安全保护已启用").font(.headline); Text("钥匙串凭证 · HTTPS 传输 · 账号级数据隔离").font(.caption).opacity(0.78) }
            Spacer()
        }.foregroundStyle(ACETheme.onPrimary).padding(18).background(ACETheme.heroGradient).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct PrivacyCenterView: View {
    var body: some View {
        SettingsScreen(title: "隐私与数据", subtitle: "清楚说明收集什么、为什么使用，以及你如何行使权利。") {
            HStack(spacing: 10) {
                privacyMetric("视频", "仅用于分析", "video.fill")
                privacyMetric("账号", "用于隔离", "person.fill")
                privacyMetric("跟踪", "不用于广告", "eye.slash.fill")
            }
            SettingsLabel(title: "数据控制")
            ACEGroupCard {
                VStack(spacing: 0) {
                    NavigationLink { DataInventoryView() } label: { ACESettingsRow(icon: "externaldrive.fill", title: "我们处理的数据", subtitle: "账号、视频、运动员资料与报告") }.buttonStyle(.plain)
                    Divider().overlay(ACETheme.cardLine).padding(.leading, 66)
                    NavigationLink { AccountDeletionInformationView() } label: { ACESettingsRow(icon: "trash.fill", title: "删除与注销", subtitle: "了解删除范围和申请流程", tint: ACETheme.danger) }.buttonStyle(.plain)
                }
            }
            SettingsLabel(title: "法律文件")
            ACEGroupCard {
                VStack(spacing: 0) {
                    NavigationLink { PrivacyPolicyView() } label: { ACESettingsRow(icon: "doc.text.fill", title: "隐私政策", subtitle: "版本 1.0 · 2026年8月10日") }.buttonStyle(.plain)
                    Divider().overlay(ACETheme.cardLine).padding(.leading, 66)
                    NavigationLink { TermsOfServiceView() } label: { ACESettingsRow(icon: "signature", title: "用户服务协议", subtitle: "版本 1.0 · 2026年8月10日") }.buttonStyle(.plain)
                }
            }
            infoPanel(icon: "person.badge.shield.checkmark", title: "你的权利", text: "你可以查阅、更正、复制或删除个人信息，撤回非必要授权，并对处理规则提出说明请求。")
        }
    }
    private func privacyMetric(_ value: String, _ caption: String, _ icon: String) -> some View {
        VStack(spacing: 7) { Image(systemName: icon).foregroundStyle(ACETheme.green); Text(value).font(.subheadline.bold()).foregroundStyle(ACETheme.cardInk); Text(caption).font(.caption2).foregroundStyle(ACETheme.cardMuted).multilineTextAlignment(.center) }
            .frame(maxWidth: .infinity).padding(.vertical, 15).background(ACETheme.paper).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct DataInventoryView: View {
    var body: some View {
        SettingsScreen(title: "数据清单", subtitle: "ACE Review 只处理提供服务所需的信息。") {
            dataCard("账号与身份", "用户名、用户标识、所属组织和角色", "用于登录、鉴权和组织内数据隔离", "person.text.rectangle")
            dataCard("训练内容", "你主动选择的视频、视频内音频、标题、备注和拍摄信息", "用于上传、切片、动作识别和生成报告", "video.fill")
            dataCard("运动员资料", "姓名或昵称、性别、水平、惯用手和训练目标", "用于提供更贴合个人情况的分析建议", "figure.tennis")
            dataCard("分析结果", "动作特征、回合、逐拍结论、评分、建议和报告", "用于呈现复盘结果并形成训练趋势", "chart.bar.doc.horizontal")
            dataCard("运行与安全", "必要的请求日志、错误信息、设备与会话安全信息", "用于防滥用、故障定位和保障服务稳定", "shield.lefthalf.filled")
        }
    }
    private func dataCard(_ title: String, _ data: String, _ purpose: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { ACEIconBadge(systemImage: icon); Text(title).font(.headline).foregroundStyle(ACETheme.cardInk) }
            Text(data).font(.subheadline).foregroundStyle(ACETheme.cardInk)
            Text("用途：\(purpose)").font(.caption).foregroundStyle(ACETheme.cardMuted)
        }.aceCard()
    }
}

struct AccountDeletionInformationView: View {
    var body: some View {
        SettingsScreen(title: "账号注销", subtitle: "注销是不可逆操作。提交前请先下载或保存仍需使用的报告。") {
            infoPanel(icon: "exclamationmark.triangle.fill", title: "注销后会发生什么", text: "账号将无法登录；账号直接关联的训练视频、运动员资料、分析任务和报告将进入删除流程。法律法规要求留存的安全、交易或审计记录，会在法定期限内隔离保存，到期后删除。")
            infoPanel(icon: "checkmark.shield.fill", title: "身份与任务核验", text: "为防止账号被冒用，我们会核验申请人身份，并确认没有未完成的上传、分析任务或尚待处理的组织责任。核验期间账号与数据仍按原有权限受到保护。")
            VStack(alignment: .leading, spacing: 10) {
                Text("如何提出申请").font(.headline).foregroundStyle(ACETheme.cardInk)
                Text("请通过“我的－帮助与支持”中的账号与隐私支持指引，或 App Store 产品页面公示的支持渠道提出申请。我们将在核验身份后告知处理进度和结果。")
                    .font(.subheadline).foregroundStyle(ACETheme.cardMuted)
            }.aceCard()
        }
    }
}

struct SupportView: View {
    @State private var expanded: String?
    var body: some View {
        SettingsScreen(title: "帮助与支持", subtitle: "先快速定位上传、分析和报告问题；联系支持时可附上任务名称与时间。") {
            supportHero
            SettingsLabel(title: "常见问题")
            faq("为什么视频一直在排队？", "多段视频会串行上传以保证稳定；每段上传完成后，云端分析会并行进行。", "queue")
            faq("退出页面会中断吗？", "不会。上传状态与云端任务会持续保存，重新进入任务库即可查看最新进度。", "arrow.triangle.2.circlepath")
            faq("为什么阶段评分会变化？", "Cut 模式下，解析任一回合后会先生成阶段评分；解析更多回合后覆盖度提高，评分会自动更新。", "chart.line.uptrend.xyaxis")
            faq("哪些视频可以使用？", "应用会读取你选择的原视频，云端兼容常见视频与音频编码；如遇失败，请保留任务时间用于诊断。", "film.stack")
            SettingsLabel(title: "问题诊断")
            infoPanel(icon: "stethoscope", title: "提交问题时请包含", text: "账号名、任务名称、发生时间、当前网络类型、错误提示截图；不要发送登录密码或短信验证码。")
            Text("账号与隐私问题可通过账号所属组织管理员，或 App Store 产品页面公示的支持渠道反馈。")
                .font(.caption).foregroundStyle(ACETheme.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
        }
    }
    private var supportHero: some View {
        HStack(spacing: 14) { Image(systemName: "lifepreserver.fill").font(.system(size: 30)); VStack(alignment: .leading, spacing: 4) { Text("我们来一起解决").font(.headline); Text("常见问题、任务诊断与隐私支持").font(.caption).opacity(0.78) }; Spacer() }
            .foregroundStyle(ACETheme.onPrimary).padding(18).background(ACETheme.heroGradient).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    private func faq(_ title: String, _ answer: String, _ icon: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { expanded = expanded == title ? nil : title } } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) { ACEIconBadge(systemImage: icon); Text(title).font(.subheadline.weight(.semibold)); Spacer(); Image(systemName: expanded == title ? "chevron.up" : "chevron.down").font(.caption.bold()).foregroundStyle(ACETheme.cardMuted) }
                if expanded == title { Text(answer).font(.subheadline).foregroundStyle(ACETheme.cardMuted).padding(.leading, 52).transition(.opacity.combined(with: .move(edge: .top))) }
            }.foregroundStyle(ACETheme.cardInk).aceCard()
        }.buttonStyle(.plain)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(title: "隐私政策", version: "1.0", sections: privacySections)
    }
    private var privacySections: [LegalSection] {[
        .init("一、适用范围与运营者", "本政策适用于 ACE Review iOS 应用及配套云端分析服务。向你提供账号和服务的 ACE Review 运营主体在 App Store 产品页面、登录页面或所属组织提供的服务说明中公示，以下称“我们”。"),
        .init("二、我们如何收集和使用信息", "为创建账号与鉴权，我们处理用户名、用户标识、组织和角色信息。为完成训练复盘，我们处理你主动选择上传的视频及其中的音频、标题、备注、拍摄时间或地点，以及你主动填写的运动员姓名或昵称、性别、水平、惯用手和训练目标。云端会据此生成动作特征、回合、逐拍结论、评分、建议、网页报告和 PDF。我们还会处理必要的请求日志、错误和会话安全信息，用于防滥用、排障与保障服务稳定。"),
        .init("三、处理原则与法律基础", "我们遵循合法、正当、必要、诚信和最小范围原则，以履行你请求的服务、取得同意、履行法定义务或保障网络与数据安全为相应处理基础。选择运动员资料、备注和拍摄地点属于可选项；拒绝提供不会影响基础账号功能，但可能降低个性化程度。"),
        .init("四、视频、音频与智能分析", "视频和音频仅用于你发起的上传、转码、切片、动作识别、质量校验、报告生成与展示，不用于广告跟踪。分析结论由自动化系统辅助生成，可能受拍摄角度、遮挡、帧率、光照和样本覆盖影响，仅供训练参考，不构成医疗诊断或伤病治疗意见。对重要结论应结合教练或专业人员判断。"),
        .init("五、共享、委托处理与转移", "除为提供云计算、对象存储、内容分发、消息通知、安全防护等必要能力而委托服务商处理，或法律法规另有要求外，我们不会出售个人信息。我们会要求受托服务商仅按约定目的、期限和安全要求处理数据。处理者发生实质变化时，将通过本政策更新或其他显著方式告知。发生合并、分立或资产转让时，将依法告知接收方并要求其继续受本政策约束。"),
        .init("六、保存地点与期限", "个人信息在实现本政策所述目的所需的最短期限内保存。账号存续期间，训练视频、任务和报告用于持续提供复盘与趋势服务；你删除相应内容、注销账号或保存目的不再存在后，我们将按流程删除或匿名化。备份副本会在合理的系统清理周期内移除；法律法规要求保留的，隔离保存且不再用于其他目的。"),
        .init("七、安全保护", "我们采用传输加密、iOS 钥匙串凭证存储、访问控制、组织与账号隔离、日志审计、备份和最小权限等措施。互联网服务无法保证绝对安全；发生可能危害你权益的事件时，我们将依法采取补救并告知事件情况、影响、措施和风险降低建议。"),
        .init("八、你的权利", "你可以依法请求查阅、复制、更正、补充、限制处理或删除个人信息，撤回基于同意的授权，注销账号，并要求解释处理规则。撤回同意不影响撤回前处理的合法性。为保障安全，我们可能在响应前核验身份。若无法满足请求，将说明理由并提供申诉渠道。"),
        .init("九、未成年人", "本服务面向具备相应民事行为能力的用户。处理不满十四周岁未成年人的个人信息前，应取得监护人单独同意并适用专门的未成年人个人信息处理规则；未完成该能力前，不应由未成年人自行注册或上传可识别视频。"),
        .init("十、权限说明", "照片权限仅在你选择训练视频时使用；你可在 iOS 系统设置中撤回。通知权限仅用于上传或分析状态提醒。拒绝非必要权限不会影响无关功能。"),
        .init("十一、政策更新与联系", "重大变更将通过应用内显著提示重新告知，依法需要同意的将再次征得同意。你可通过“我的－帮助与支持”、账号所属组织管理员，或 App Store 产品页面公示的支持渠道提出隐私咨询、权利请求或投诉。我们会在验证身份后依法处理并反馈。生效日期：2026年8月10日。")
    ]}
}

struct TermsOfServiceView: View {
    var body: some View { LegalDocumentView(title: "用户服务协议", version: "1.0", sections: sections) }
    private var sections: [LegalSection] {[
        .init("一、协议接受", "当你注册、登录或使用 ACE Review，即表示你已阅读并同意本协议及隐私政策。若你不同意，应停止使用。未成年人应由监护人阅读并同意后使用。"),
        .init("二、服务内容", "ACE Review 提供训练视频上传、云端转码与分析、回合切片、逐拍解析、训练建议、趋势和报告查看等功能。具体能力以实际版本、账号权限和服务状态为准。"),
        .init("三、账号责任", "你应提供真实、合法且必要的信息，妥善保管密码和设备，不得出借账号或绕过权限。发现异常使用应及时修改密码并联系支持。因你主动泄露凭证造成的风险由相应责任方依法承担。"),
        .init("四、上传内容与授权", "你应确保有权上传视频、音频和运动员资料，并已取得画面中可识别人员所需授权。你保留上传内容的合法权利，同时授予运营者在提供本服务所必需范围和期限内进行存储、转码、分析、生成及展示报告的非独占授权。"),
        .init("五、使用规范", "不得上传违法侵权、恶意代码或与训练复盘无关的内容；不得攻击服务、批量爬取、反向破解、冒用他人身份或利用分析结果侵害他人权益。违规时可依法限制功能、暂停服务并保留证据。"),
        .init("六、智能分析说明", "自动分析结果受视频质量、人物遮挡、设备参数和模型能力影响，可能存在误差。评分用于同一产品规则下的训练参考，不应作为医疗诊断、伤病处置、选拔录取或其他高风险决策的唯一依据。"),
        .init("七、服务变更与中断", "为维护、安全升级或不可抗力，服务可能短时中断。我们将尽合理努力提前通知、缩短影响并恢复服务。涉及付费权益的，退款和补偿按购买页面、适用平台规则及法律法规执行。"),
        .init("八、知识产权", "应用软件、界面、算法、商标和运营内容的权利归相应权利人所有。未经书面许可，不得复制、改编、出售或用于建立竞争性服务。用户上传内容及依法享有的训练数据权益不因本协议转移。"),
        .init("九、责任边界", "我们依法对因故意或重大过失造成的损害承担责任。对可归责于网络、设备、第三方平台或用户操作的影响，将根据过错和法律规定承担相应责任；本条不排除法律不得限制的消费者权利。"),
        .init("十、终止、法律与争议", "你可停止使用并按隐私政策申请注销。协议终止不影响终止前已产生的合法权利义务。本协议的订立、履行与解释适用中华人民共和国法律。争议发生时，双方应先友好协商；协商不成的，可依法向有管辖权的人民法院提起诉讼。生效日期：2026年8月10日。")
    ]}
}

struct LegalSection: Identifiable { let id = UUID(); let title: String; let body: String; init(_ title: String, _ body: String) { self.title = title; self.body = body } }

struct LegalDocumentView: View {
    let title: String
    let version: String
    let sections: [LegalSection]
    var body: some View {
        SettingsScreen(title: title, subtitle: "版本 \(version) · 生效日期 2026年8月10日") {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.title).font(.headline).foregroundStyle(ACETheme.cardInk)
                    Text(section.body).font(.system(size: 15)).foregroundStyle(ACETheme.cardMuted).lineSpacing(6).textSelection(.enabled)
                }.aceCard()
            }
        }
    }
}

private func infoPanel(icon: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 13) {
        ACEIconBadge(systemImage: icon)
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline).foregroundStyle(ACETheme.cardInk); Text(text).font(.subheadline).foregroundStyle(ACETheme.cardMuted).fixedSize(horizontal: false, vertical: true) }
        Spacer(minLength: 0)
    }.aceCard()
}
