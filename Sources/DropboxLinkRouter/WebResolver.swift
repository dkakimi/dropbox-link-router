import AppKit
import WebKit

/// ログイン済みの WebView で共有リンクを開き、フォルダ名やパスを読み取る。
/// ログイン状態は WKWebsiteDataStore.default() に永続化される。
@MainActor
final class WebResolver: NSObject, WKNavigationDelegate, WKUIDelegate {
    struct Result {
        /// 最終的な URL（/home/... にリダイレクトされればパスが分かる）
        var finalURL: URL?
        /// ページタイトルから取ったフォルダ名
        var name: String?
        /// パンくずリスト（ルート側から順）
        var breadcrumb: [String]
        /// ログインが必要そうか
        var needsLogin: Bool

        /// リンク先が削除済み・存在しない
        var isDeleted: Bool {
            guard let name else { return false }
            return ["削除しました", "削除されました", "見つかりません", "deleted", "not found", "doesn’t exist", "doesn't exist"]
                .contains { name.localizedCaseInsensitiveContains($0) }
        }
    }

    static let shared = WebResolver()

    private var window: NSWindow?
    private var loginWindow: NSWindow?

    func resolve(_ url: URL, timeout: TimeInterval = 15) async -> Result {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 900),
                                configuration: Self.configuration())
        webView.customUserAgent = Self.userAgent
        // オフスクリーンのウィンドウに載せないと JS が間引かれることがある
        let win = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 1280, height: 900),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = webView
        win.orderBack(nil)
        window = win
        defer { win.orderOut(nil); window = nil }

        webView.load(URLRequest(url: url))

        let deadline = Date().addingTimeInterval(timeout)
        var last = Result(finalURL: nil, name: nil, breadcrumb: [], needsLogin: false)
        var namedAt: Date?
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(500))
            last = await snapshot(webView)
            if last.needsLogin || last.isDeleted { break }
            if let u = last.finalURL, u.path.hasPrefix("/home") { break }
            if last.name != nil, !last.breadcrumb.isEmpty { break }
            // タイトルが出てから 3 秒待っても /home に飛ばなければ見切る
            if last.name != nil {
                namedAt = namedAt ?? Date()
                if Date().timeIntervalSince(namedAt!) > 3 { break }
            }
        }
        // パンくずが出るまで待ち切れなかった場合も、名前があれば返す
        log.notice("web resolve final=\(last.finalURL?.absoluteString ?? "-", privacy: .public) name=\(last.name ?? "-", privacy: .public) crumbs=\(last.breadcrumb.joined(separator: " / "), privacy: .public) login=\(last.needsLogin)")
        return last
    }

    private func snapshot(_ webView: WKWebView) async -> Result {
        let js = """
        (() => {
          const text = el => (el.innerText || el.textContent || '').trim();
          const sel = [
            'nav[aria-label*="breadcrumb" i] a, nav[aria-label*="breadcrumb" i] span',
            '[data-testid*="breadcrumb" i]',
            '[class*="breadcrumb" i] a, [class*="breadcrumb" i] span'
          ];
          let crumbs = [];
          for (const s of sel) {
            crumbs = [...document.querySelectorAll(s)].map(text).filter(t => t && t.length < 200);
            if (crumbs.length) break;
          }
          const loginForm = !!document.querySelector('input[type="password"], form[action*="login"]');
          return JSON.stringify({ title: document.title, crumbs: [...new Set(crumbs)], loginForm });
        })()
        """
        var name: String?
        var crumbs: [String] = []
        var loginForm = false
        if let json = try? await webView.evaluateJavaScript(js) as? String,
           let data = json.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let title = obj["title"] as? String { name = Self.folderName(fromTitle: title) }
            crumbs = obj["crumbs"] as? [String] ?? []
            loginForm = obj["loginForm"] as? Bool ?? false
        }
        let url = webView.url
        let needsLogin = loginForm || (url?.path.hasPrefix("/login") ?? false)
        return Result(finalURL: url, name: name, breadcrumb: crumbs, needsLogin: needsLogin)
    }

    /// 「フォルダ名 - Dropbox」のようなタイトルから名前を取り出す。
    static func folderName(fromTitle title: String) -> String? {
        var t = title.trimmingCharacters(in: .whitespaces)
        for suffix in [" - Dropbox", " – Dropbox", " | Dropbox"] where t.hasSuffix(suffix) {
            t = String(t.dropLast(suffix.count))
        }
        if t.isEmpty || t == "Dropbox" { return nil }
        return t
    }

    /// ログイン用ウィンドウを表示する。
    func showLogin() {
        if let loginWindow { loginWindow.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let webView = WKWebView(frame: .zero, configuration: Self.configuration())
        webView.customUserAgent = Self.userAgent
        webView.uiDelegate = self
        webView.load(URLRequest(url: URL(string: "https://www.dropbox.com/login")!))
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 760),
                           styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        win.title = "Dropbox にログイン（ログイン後はこのウィンドウを閉じてOK）"
        win.contentView = webView
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate()
        loginWindow = win
    }

    private static func configuration() -> WKWebViewConfiguration {
        let c = WKWebViewConfiguration()
        c.websiteDataStore = .default()
        c.preferences.javaScriptCanOpenWindowsAutomatically = true
        return c
    }

    // MARK: - ポップアップ（Google ログインなど）

    private var popups: [NSWindow] = []

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // 渡された configuration を使わないと window.opener が繋がらずログインが完了しない
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.customUserAgent = Self.userAgent
        popup.uiDelegate = self
        let size = NSSize(width: windowFeatures.width?.doubleValue ?? 520,
                          height: windowFeatures.height?.doubleValue ?? 680)
        let win = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                           styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        win.title = "ログイン"
        win.contentView = popup
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        popups.append(win)
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        popups.removeAll { win in
            guard win.contentView === webView else { return false }
            win.close()
            return true
        }
    }

    // 組み込み WebView と判定されて弾かれないよう Safari の UA を名乗る
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
}
