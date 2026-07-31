import Foundation
import SwiftUI

enum ACETheme {
    static let ink = Color(red: 0.12, green: 0.17, blue: 0.14)
    static let green = Color(red: 0.26, green: 0.43, blue: 0.31)
    static let lime = Color(red: 0.62, green: 0.74, blue: 0.53)
    static let coral = Color(red: 0.76, green: 0.48, blue: 0.34)
    static let cream = Color(red: 0.98, green: 0.985, blue: 0.965)
    static let paper = Color.white
    static let muted = Color(red: 0.40, green: 0.46, blue: 0.40)
    static let line = Color(red: 0.84, green: 0.87, blue: 0.81)
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
}
