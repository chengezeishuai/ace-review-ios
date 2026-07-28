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
        if let token = KeychainStore.get("accessToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let cookie = HTTPCookie(properties: [
                .domain: baseURL.host ?? "",
                .path: "/",
                .name: "ace_review_session",
                .value: token,
                .secure: baseURL.scheme == "https" ? "TRUE" : "FALSE"
            ]) {
                webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
                    webView.load(request)
                }
                return
            }
        }
        webView.load(request)
    }
}
