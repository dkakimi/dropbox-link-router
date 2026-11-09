import AppKit
import OSLog
import RouterCore

let log = Logger(subsystem: "com.dkakimi.DropboxLinkRouter", category: "router")

/// 受け取った URL を Finder かブラウザに振り分ける。
@MainActor
final class LinkRouter {
    private let settings: BrowserSettings

    init(settings: BrowserSettings) {
        self.settings = settings
    }

    func handle(_ url: URL) async {
        // await より前に読む（検索中に ⌥ を離しても判定がぶれないように）
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        let link = DropboxLink.parse(url)
        log.notice("received url=\(url.absoluteString, privacy: .public) parsed=\(String(describing: link), privacy: .public) option=\(optionHeld)")

        guard !optionHeld, let link else {
            openInBrowser(url)
            return
        }

        let finder = LocalFileFinder()
        log.notice("roots=\(finder.roots.map(\.path).joined(separator: ", "), privacy: .public)")

        switch link {
        case .file(let name):
            await handleShared(url, fileName: name, finder: finder)
        case .folder:
            await handleShared(url, fileName: nil, finder: finder)
        case .other:
            openInBrowser(url)
        }
    }

    /// ログイン済み WebView で共有リンクを開き、/home/... へのリダイレクトからパスを得る。
    /// だめならファイル名（またはページタイトル）で検索する。
    private func handleShared(_ url: URL, fileName: String?, finder: LocalFileFinder) async {
        let r = await WebResolver.shared.resolve(url)

        if r.isDeleted {
            notify("リンク先は Dropbox 上で削除されています（\(r.name ?? "")）。ブラウザで開きます。")
            openInBrowser(url)
            return
        }
        if let final = r.finalURL,
           let local = LocalFileFinder.localPath(forHomeURL: final, roots: finder.roots) {
            await reveal([local], original: url)
            return
        }
        if let fileName {
            await reveal(await finder.find(named: fileName), original: url)
            return
        }
        if r.needsLogin {
            notify("Dropbox へのログインが必要です。ログイン後にもう一度リンクをクリックしてください。")
            WebResolver.shared.showLogin()
            return
        }
        guard let name = r.name else {
            notify("フォルダ名を読み取れなかったため、ブラウザで開きます。")
            openInBrowser(url)
            return
        }
        let matches = LocalFileFinder.rank(await finder.find(named: name), breadcrumb: r.breadcrumb)
        await reveal(matches, original: url)
    }

    private func reveal(_ matches: [URL], original: URL) async {
        log.notice("matches=\(matches.count) \(matches.map(\.path).joined(separator: ", "), privacy: .public)")
        switch matches.count {
        case 0:
            notify("ローカルの Dropbox に見つからなかったため、ブラウザで開きます。")
            openInBrowser(original)
        case 1:
            showInFinder(matches[0])
        default:
            choose(from: matches, original: original)
        }
    }

    /// フォルダなら中身を開き、ファイルなら選択状態で表示する。
    private func showInFinder(_ url: URL) {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        if isDir {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func notify(_ message: String) {
        log.notice("notify: \(message, privacy: .public)")
        let alert = NSAlert()
        alert.messageText = "Dropbox Link Router"
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }

    func openInBrowser(_ url: URL) {
        guard let browser = settings.effectiveFallback else {
            NSLog("転送先ブラウザが見つかりません: \(url)")
            return
        }
        // NSWorkspace.open(url) だと自分自身に戻ってきてループするので、必ずアプリを指定する
        NSWorkspace.shared.open([url], withApplicationAt: browser, configuration: NSWorkspace.OpenConfiguration())
    }

    /// 同名ファイルが複数ある場合はマウス位置にメニューを出して選ばせる。
    private func choose(from matches: [URL], original: URL) {
        let menu = NSMenu()
        let roots = LocalFileFinder.dropboxRoots()
        for file in matches {
            let item = MenuActionItem(title: displayPath(file, roots: roots)) { [weak self] in
                self?.showInFinder(file)
            }
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(MenuActionItem(title: "ブラウザで開く") { [weak self] in
            self?.openInBrowser(original)
        })

        NSApp.activate()
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func displayPath(_ file: URL, roots: [URL]) -> String {
        for root in roots where file.path.hasPrefix(root.path + "/") {
            return root.lastPathComponent + String(file.path.dropFirst(root.path.count))
        }
        return file.path
    }
}

/// クロージャで動作する NSMenuItem
private final class MenuActionItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}
