import Foundation
import SwiftUI

enum ACETheme {
    static let ink = Color(red: 0.02, green: 0.13, blue: 0.11)
    static let green = Color(red: 0.02, green: 0.29, blue: 0.22)
    static let lime = Color(red: 0.74, green: 0.94, blue: 0.20)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.91)
    static let paper = Color(red: 1.00, green: 0.99, blue: 0.96)
    static let muted = Color(red: 0.40, green: 0.44, blue: 0.41)
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private static let serverKey = "ace.serverURL"

    @Published var serverURLString: String {
        didSet { UserDefaults.standard.set(serverURLString, forKey: Self.serverKey) }
    }

    private init() {
        serverURLString = UserDefaults.standard.string(forKey: Self.serverKey)
            ?? "http://36.140.125.194:19999/"
    }

    var baseURL: URL {
        let normalized = serverURLString.hasSuffix("/")
            ? serverURLString
            : serverURLString + "/"
        return URL(string: normalized)
            ?? URL(string: "http://36.140.125.194:19999/")!
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ACETheme.green.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func aceCard() -> some View {
        self
            .padding(18)
            .background(ACETheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            }
    }
}

