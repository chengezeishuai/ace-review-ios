import SwiftUI
import WebKit

struct AuthenticatedWebView: UIViewRepresentable {
    let path: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        if let token = KeychainStore.get("accessToken") {
            let escaped = token.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            let script = """
            (() => {
              const token = 'Bearer (escaped)';
              const originalFetch = window.fetch;
              window.fetch = (input, init = {}) => {
                const headers = new Headers(init.headers || {});
                headers.set('Authorization', token);
                headers.set('clientid', '(AppSettings.shared.clientID)');
                return originalFetch(input, {...init, headers, credentials: 'include'});
              };
            })();
            """
            configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
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
            if path.contains("/video") || path.contains("/report/pdf") {
                var components = URLComponents(url: target, resolvingAgainstBaseURL: false)
                var items = components?.queryItems ?? []
                items.append(URLQueryItem(name: "Authorization", value: "Bearer \(token)"))
                items.append(URLQueryItem(name: "clientid", value: AppSettings.shared.clientID))
                components?.queryItems = items
                if let url = components?.url { request.url = url }
            }
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
