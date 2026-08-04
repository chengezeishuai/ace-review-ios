import Foundation
import SwiftUI
import UIKit

struct ACEPalette: Identifiable, Equatable {
    let id: String
    let name: String
    let primary: String
    let accent: String
    let background: String
    let card: String

    static let presets = [
        ACEPalette(id: "hard-blue", name: "澳网硬地", primary: "167FAE", accent: "71C9E8", background: "F2F8FB", card: "FFFFFF"),
        ACEPalette(id: "hard-green", name: "美网硬地", primary: "12865D", accent: "2EBF7B", background: "F1F8F4", card: "FFFFFF"),
        ACEPalette(id: "grass", name: "温网草地", primary: "3E742F", accent: "86B74B", background: "F4F8EF", card: "FFFFFF"),
        ACEPalette(id: "clay", name: "法网红土", primary: "A94622", accent: "E26A2C", background: "FBF3EC", card: "FFFDFC")
    ]
}

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()
    private let defaults = UserDefaults.standard
    @Published var selectedID: String { didSet { defaults.set(selectedID, forKey: "ace.theme.id"); revision += 1 } }
    @Published var customPrimary: String { didSet { defaults.set(customPrimary, forKey: "ace.theme.custom.primary") } }
    @Published var customAccent: String { didSet { defaults.set(customAccent, forKey: "ace.theme.custom.accent") } }
    @Published var customBackground: String { didSet { defaults.set(customBackground, forKey: "ace.theme.custom.background") } }
    @Published var customCard: String { didSet { defaults.set(customCard, forKey: "ace.theme.custom.card") } }
    @Published private(set) var revision = 0

    private init() {
        selectedID = defaults.string(forKey: "ace.theme.id") ?? "grass"
        customPrimary = defaults.string(forKey: "ace.theme.custom.primary") ?? "416D4E"
        customAccent = defaults.string(forKey: "ace.theme.custom.accent") ?? "9EBD87"
        customBackground = defaults.string(forKey: "ace.theme.custom.background") ?? "FAFBF6"
        customCard = defaults.string(forKey: "ace.theme.custom.card") ?? "FFFFFF"
    }

    var palette: ACEPalette {
        if selectedID == "custom" {
            return ACEPalette(id: "custom", name: "自定义", primary: customPrimary, accent: customAccent, background: customBackground, card: customCard)
        }
        return ACEPalette.presets.first(where: { $0.id == selectedID }) ?? ACEPalette.presets[2]
    }

    func applyCustom() {
        if selectedID == "custom" { revision += 1 }
        else { selectedID = "custom" }
    }
}

extension Color {
    init(aceHex value: String) {
        let hex = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let number = UInt64(hex, radix: 16) ?? 0
        self.init(.sRGB, red: Double((number >> 16) & 0xFF) / 255, green: Double((number >> 8) & 0xFF) / 255, blue: Double(number & 0xFF) / 255, opacity: 1)
    }

    var aceHex: String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let red = components[0]
        let green = components.count > 2 ? components[1] : components[0]
        let blue = components.count > 2 ? components[2] : components[0]
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

enum ACETheme {
    private static var palette: ACEPalette { ThemeStore.shared.palette }
    static var ink: Color { Color(aceHex: "17231C") }
    static var green: Color { Color(aceHex: palette.primary) }
    static var lime: Color { Color(aceHex: palette.accent) }
    static var coral: Color { Color(aceHex: palette.accent) }
    static var cream: Color { Color(aceHex: palette.background) }
    static var paper: Color { Color(aceHex: palette.card) }
    static var muted: Color { green.opacity(0.70) }
    static var line: Color { green.opacity(0.20) }
}

struct ACEBackground: View {
    var body: some View {
        ACETheme.cream.ignoresSafeArea()
    }
}

struct ACEBrandMark: View {
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            Circle().fill(ACETheme.green)
            Circle().stroke(ACETheme.lime.opacity(0.72), lineWidth: size * 0.05).padding(size * 0.15)
            Circle().trim(from: 0.12, to: 0.47).stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round)).rotationEffect(.degrees(-18)).padding(size * 0.24)
        }.frame(width: size, height: size)
    }
}

final class AppSettings {
    static let shared = AppSettings()
    let baseURL: URL
    let configurationError: String?
    // Matches the RuoYi mobile client registration.
    let clientID = "e5cd7e4891bf95d1d19206ce24a7b32e"
    private init() {
        let rawURL = Bundle.main.object(forInfoDictionaryKey: "ACEAPIBaseURL") as? String ?? ""
        let isPlaceholder = rawURL.localizedCaseInsensitiveContains("replace_with_ace_domain")
        guard let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false,
              !isPlaceholder else {
            // A bad build setting must never crash a customer's app. Network
            // calls surface this message through the normal UI instead.
            baseURL = URL(string: "https://api.invalid/")!
            configurationError = "服务地址尚未配置，请联系平台管理员。"
            return
        }
        baseURL = url
        configurationError = nil
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 24)
            .padding(.vertical, 15)
            .background(ACETheme.green.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct PrimaryActionLabel: View {
    let title: String
    var systemImage: String?
    var isWorking = false

    var body: some View {
        HStack(spacing: 9) {
            if isWorking {
                ProgressView()
                    .tint(.white)
            }
            Text(title)
                .multilineTextAlignment(.center)
            if let systemImage, !isWorking {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

extension View {
    func aceCard() -> some View {
        self
            .padding(20)
            .background(ACETheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(ACETheme.line.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: ACETheme.green.opacity(0.07), radius: 16, y: 6)
    }
}
