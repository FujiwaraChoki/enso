import SwiftUI
import WebKit

/// WKWebView subclass that disables internal scrolling
class NonScrollingWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        // Pass scroll events to the next responder (parent ScrollView)
        nextResponder?.scrollWheel(with: event)
    }
}

/// A SwiftUI wrapper around WKWebView for rendering HTML email content with dynamic height
struct EmailWebView: NSViewRepresentable {
    let html: String
    @Binding var dynamicHeight: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Enable JavaScript for height measurement only
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = NonScrollingWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        return webView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WKWebView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return CGSize(width: width, height: dynamicHeight)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only reload if HTML changed
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            let styledHTML = wrapHTMLWithStyles(html)
            webView.loadHTMLString(styledHTML, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dynamicHeight: $dynamicHeight)
    }

    /// Wraps HTML content with styling to match the app's appearance
    private func wrapHTMLWithStyles(_ html: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                :root {
                    color-scheme: light dark;
                }
                html, body {
                    margin: 0;
                    padding: 0;
                    background-color: transparent;
                    overflow: hidden;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.5;
                    color: #1d1d1f;
                    padding: 16px;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #f5f5f7;
                    }
                    a {
                        color: #6eb6ff;
                    }
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                a {
                    color: #0066cc;
                }
                pre, code {
                    background-color: rgba(128, 128, 128, 0.1);
                    border-radius: 4px;
                    padding: 2px 6px;
                    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
                    font-size: 13px;
                    overflow-x: auto;
                }
                blockquote {
                    border-left: 3px solid #ccc;
                    margin-left: 0;
                    padding-left: 16px;
                    color: #666;
                }
                table {
                    border-collapse: collapse;
                    max-width: 100%;
                }
                td, th {
                    padding: 8px;
                }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var dynamicHeight: Binding<CGFloat>
        var lastHTML: String = ""

        init(dynamicHeight: Binding<CGFloat>) {
            self.dynamicHeight = dynamicHeight
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Measure content height after page loads
            let js = "Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.scrollHeight)"
            webView.evaluateJavaScript(js) { [weak self] result, error in
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        self?.dynamicHeight.wrappedValue = height
                    }
                }
            }
        }

        /// Open links in the default browser instead of in the WebView
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

#Preview {
    @Previewable @State var height: CGFloat = 100
    EmailWebView(html: """
        <h1>Test Email</h1>
        <p>This is a <strong>test</strong> email with some <a href="https://apple.com">links</a>.</p>
        <blockquote>Quoted text here</blockquote>
        <pre><code>let x = 42</code></pre>
    """, dynamicHeight: $height)
    .frame(width: 600, height: height)
}
