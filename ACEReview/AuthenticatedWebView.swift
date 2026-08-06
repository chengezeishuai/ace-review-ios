import SwiftUI
import WebKit

struct AuthenticatedWebView: UIViewRepresentable {
    let path: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "cutAnalyze")
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
        let cutBridge = """
        document.addEventListener('click', function(event) {
          const button = event.target.closest && event.target.closest('[data-cut-analyze]');
          if (!button || !window.webkit || !window.webkit.messageHandlers.cutAnalyze) return;
          event.preventDefault();
          event.stopImmediatePropagation();
          if (button.disabled) return;
          button.disabled = true;
          button.textContent = '生成中…';
          window.webkit.messageHandlers.cutAnalyze.postMessage(button.dataset.cutAnalyze);
        }, true);
        """
        configuration.userContentController.addUserScript(WKUserScript(source: cutBridge, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
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
                // Sa-Token treats query parameters as the raw token, unlike
                // the HTTP header which requires the Bearer prefix.
                items.append(URLQueryItem(name: "Authorization", value: token))
                items.append(URLQueryItem(name: "clientid", value: AppSettings.shared.clientID))
                components?.queryItems = items
                if let url = components?.url { request.url = url }
            }
            let cookieHeader = [
                "Set-Cookie": [
                    "Authorization=\(token)",
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
                    let legacyHeader = [
                        "Set-Cookie": "ace_review_session=\(token); Path=/; Max-Age=\(30 * 24 * 60 * 60); SameSite=Lax"
                    ]
                    if let legacy = HTTPCookie.cookies(withResponseHeaderFields: legacyHeader, for: baseURL).first {
                        webView.configuration.websiteDataStore.httpCookieStore.setCookie(legacy) {
                            webView.load(request)
                        }
                    } else {
                        webView.load(request)
                    }
                }
                return
            }
        }
        webView.load(request)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "cutAnalyze", let path = message.body as? String else { return }
            let pattern = #"/api/app/tasks/([a-f0-9]{32})/cuts/(\d+)/analyze"#
            guard let match = try? NSRegularExpression(pattern: pattern),
                  let result = match.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
                  let taskRange = Range(result.range(at: 1), in: path),
                  let cutRange = Range(result.range(at: 2), in: path) else { return }
            let taskID = String(path[taskRange])
            let cutID = String(path[cutRange])
            Task {
                do {
                    let submitted = try await APIClient.shared.analyzeCut(taskID: taskID, cutID: cutID)
                    await MainActor.run { self.setButtons(path: path, text: "已提交，处理中 20%", disabled: true) }
                    await self.waitForCompletion(taskID: submitted.id, buttonPath: path)
                } catch {
                    await MainActor.run { self.setButtons(path: path, text: "生成本段逐拍报告", disabled: false, alert: "逐拍分析提交失败：\(error.localizedDescription)") }
                }
            }
        }

        private func waitForCompletion(taskID: String, buttonPath: String) async {
            for _ in 0..<900 {
                try? await Task.sleep(for: .seconds(2))
                do {
                    let task = try await APIClient.shared.task(id: taskID)
                    if task.status == "completed", let reportPath = task.reportURL {
                        await MainActor.run {
                            self.setButtons(path: buttonPath, text: "已生成，打开报告", disabled: false)
                            self.loadAuthenticated(reportPath)
                        }
                        return
                    }
                    if task.status == "failed" || task.status == "cancelled" {
                        await MainActor.run {
                            self.setButtons(path: buttonPath, text: "重新生成本段报告", disabled: false, alert: task.failureReason)
                        }
                        return
                    }
                    await MainActor.run {
                        self.setButtons(path: buttonPath, text: "处理中 \(max(20, min(99, task.progress)))%", disabled: true)
                    }
                } catch {
                    // A transient polling failure should not turn a valid submitted task into a false failure.
                }
            }
            await MainActor.run {
                self.setButtons(path: buttonPath, text: "后台处理中，刷新查看", disabled: false)
            }
        }

        private func loadAuthenticated(_ path: String) {
            let target = APIClient.shared.url(for: path)
            var request = URLRequest(url: target)
            request.setValue(AppSettings.shared.clientID, forHTTPHeaderField: "clientid")
            if let token = KeychainStore.get("accessToken") {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            webView?.load(request)
        }

        private func setButtons(path: String, text: String, disabled: Bool, alert: String? = nil) {
            let escapedPath = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            let alertJS = alert.map { "alert('\($0.replacingOccurrences(of: "'", with: "\\'"))');" } ?? ""
            webView?.evaluateJavaScript("document.querySelectorAll('[data-cut-analyze=\\\"\(escapedPath)\\\"]').forEach(b=>{b.textContent='\(escapedText)';b.disabled=\(disabled ? "true" : "false")});\(alertJS)")
        }
    }
}
