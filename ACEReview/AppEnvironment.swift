import Foundation
import SwiftUI

enum ACETheme {
    static let ink = Color(red: 0.055, green: 0.09, blue: 0.14)
    static let green = Color(red: 0.02, green: 0.49, blue: 0.55)
    static let lime = Color(red: 0.20, green: 0.70, blue: 0.54)
    static let coral = Color(red: 0.94, green: 0.43, blue: 0.31)
    static let cream = Color(red: 0.93, green: 0.96, blue: 0.96)
    static let paper = Color.white
    static let muted = Color(red: 0.34, green: 0.41, blue: 0.49)
    static let line = Color(red: 0.80, green: 0.85, blue: 0.86)
}

struct ACEBackground: View {
    var body: some View {
        ZStack {
            ACETheme.cream
            Circle().fill(ACETheme.lime.opacity(0.20)).frame(width: 340, height: 340).blur(radius: 34).offset(x: 150, y: -330)
            Circle().fill(ACETheme.coral.opacity(0.12)).frame(width: 270, height: 270).blur(radius: 36).offset(x: -170, y: 350)
        }.ignoresSafeArea()
    }
}

struct ACEBrandMark: View {
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [ACETheme.ink, Color(red: 0.08, green: 0.22, blue: 0.26)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(ACETheme.lime, lineWidth: size * 0.05).padding(size * 0.15)
            Circle().trim(from: 0.10, to: 0.48).stroke(ACETheme.coral, style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round)).rotationEffect(.degrees(-18)).padding(size * 0.24)
            Circle().fill(.white.opacity(0.9)).frame(width: size * 0.12, height: size * 0.12).offset(x: size * 0.16, y: -size * 0.16)
        }.frame(width: size, height: size)
    }
}

final class AppSettings {
    static let shared = AppSettings()
    let baseURL: URL
    // Matches the RuoYi mobile client registration.
    let clientID = "e5cd7e4891bf95d1d19206ce24a7b32e"
    private init() {
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "ACEAPIBaseURL") as? String,
              let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            preconditionFailure("ACE API address is not configured")
        }
#if !DEBUG
        guard scheme == "https",
              let host = url.host,
              !host.isEmpty,
              !host.localizedCaseInsensitiveContains("replace_with_ace_domain") else {
            preconditionFailure("Release builds require a configured HTTPS ACE API address")
        }
#endif
        baseURL = url
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
            .background(LinearGradient(colors: [ACETheme.green.opacity(configuration.isPressed ? 0.78 : 1), ACETheme.lime.opacity(configuration.isPressed ? 0.72 : 0.90)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
            .padding(17)
            .background(ACETheme.paper.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(ACETheme.line.opacity(0.68), lineWidth: 1)
    }
}
}
