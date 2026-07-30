import Foundation
import SwiftUI

enum ACETheme {
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let green = Color(red: 0.00, green: 0.40, blue: 0.85)
    static let lime = Color(red: 0.18, green: 0.72, blue: 0.40)
    static let cream = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let paper = Color.white
    static let muted = Color(red: 0.42, green: 0.42, blue: 0.45)
    static let line = Color(red: 0.84, green: 0.85, blue: 0.87)
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
        guard scheme == "https" else {
            preconditionFailure("Release builds require an HTTPS ACE API address")
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
            .background(ACETheme.green.opacity(configuration.isPressed ? 0.82 : 1))
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
            .background(ACETheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(ACETheme.line.opacity(0.8), lineWidth: 1)
            }
    }
}
