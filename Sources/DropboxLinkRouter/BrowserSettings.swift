import AppKit

/// 転送先ブラウザと「既定ブラウザ」登録の管理。
@MainActor
final class BrowserSettings: ObservableObject {
    static let shared = BrowserSettings()

    private let key = "fallbackBrowserPath"
    private let probeURL = URL(string: "https://example.com")!

    @Published private(set) var fallbackBrowserURL: URL?
    @Published private(set) var isDefaultBrowser = false

    private init() {
        if let path = UserDefaults.standard.string(forKey: key),
           FileManager.default.fileExists(atPath: path) {
            fallbackBrowserURL = URL(fileURLWithPath: path)
        }
        captureCurrentDefaultIfNeeded()
        refresh()
    }

    func refresh() {
        isDefaultBrowser = currentDefault().map(isSelf) ?? false
    }

    /// http を開けるがブラウザではないアプリ
    private static let nonBrowserBundleIDs: Set<String> = [
        "org.hammerspoon.Hammerspoon",
    ]

    /// 自分以外のブラウザ一覧（転送先候補）。同じアプリが複数あれば /Applications のものを優先して 1 つにする。
    var installedBrowsers: [URL] {
        var seen = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: probeURL)
            .filter { !isSelf($0) }
            .sorted { Self.locationRank($0) < Self.locationRank($1) }
            .filter { app in
                guard let id = Bundle(url: app)?.bundleIdentifier else { return true }
                guard !Self.nonBrowserBundleIDs.contains(id) else { return false }
                return seen.insert(id).inserted
            }
            .sorted { FileManager.default.displayName(atPath: $0.path)
                .localizedStandardCompare(FileManager.default.displayName(atPath: $1.path)) == .orderedAscending }
    }

    private static func locationRank(_ app: URL) -> Int {
        let p = app.path
        if p.hasPrefix("/Applications/") || p.contains("/System/") { return 0 }
        if p.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path) { return 1 }
        return 2
    }

    /// 転送先。未設定なら Safari。
    var effectiveFallback: URL? {
        fallbackBrowserURL
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari")
    }

    func setFallback(_ url: URL) {
        fallbackBrowserURL = url
        UserDefaults.standard.set(url.path, forKey: key)
    }

    /// 自分を既定ブラウザにする（macOS が確認ダイアログを出す）。
    func makeDefaultBrowser() async {
        captureCurrentDefaultIfNeeded(force: true)
        await setDefault(Bundle.main.bundleURL)
    }

    /// 記録しておいたブラウザを既定に戻す。
    func restoreDefaultBrowser() async {
        guard let browser = effectiveFallback else { return }
        await setDefault(browser)
    }

    private func setDefault(_ app: URL) async {
        for scheme in ["http", "https"] {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: scheme)
            } catch {
                NSLog("setDefaultApplication(\(scheme)) failed: \(error)")
            }
        }
        refresh()
    }

    private func currentDefault() -> URL? {
        NSWorkspace.shared.urlForApplication(toOpen: probeURL)
    }

    /// 自分が既定になる前の既定ブラウザを転送先として記録する。
    private func captureCurrentDefaultIfNeeded(force: Bool = false) {
        guard force || fallbackBrowserURL == nil,
              let current = currentDefault(), !isSelf(current) else { return }
        setFallback(current)
    }

    private func isSelf(_ app: URL) -> Bool {
        Bundle(url: app)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }
}
