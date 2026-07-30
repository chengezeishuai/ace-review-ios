import SwiftUI
import WebKit

struct AuthenticatedWebView: UIViewRepresentable {
    let path: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        load(path: path, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private func load(path: String, in webView: WKWebView) {
        let baseURL = AppSettings.shared.baseURL
        let target = APIClient.shared.url(for: path)
        var request = URLRequest(url: target)
        request.setValue(AppSettings.shared.clientID, forHTTPHeaderField: "clientid")
        if let token = KeychainStore.get("accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let cookieHeader = [
                "Set-Cookie": [
                    "ace_review_session=\(token)",
                    "Path=/",
                    "Max-Age=\(30 * 24 * 60 * 60)",
                    "HttpOnly",
                    "SameSite=Lax"
                ].joined(separator: "; ")
            ]
            if let cookie = HTTPCookie.cookies(
                withResponseHeaderFields: cookieHeader,
                for: baseURL
            ).first {
                webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
                    webView.load(request)
                }
                return
            }
        }
        webView.load(request)
    }
}
