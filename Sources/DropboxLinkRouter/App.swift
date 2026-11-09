import AppKit
import SwiftUI

@main
struct DropboxLinkRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = BrowserSettings.shared
    @StateObject private var loginItem = LoginItem.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(settings: settings, loginItem: loginItem)
        } label: {
            Image(nsImage: MenuBarIcon.make())
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var router = LinkRouter(settings: .shared)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { @MainActor in await router.handle(url) }
        }
    }
}

struct MenuContent: View {
    @ObservedObject var settings: BrowserSettings
    @ObservedObject var loginItem: LoginItem

    var body: some View {
        if settings.isDefaultBrowser {
            Text("✓ 既定ブラウザとして動作中")
            Button("元のブラウザに戻す") {
                Task { await settings.restoreDefaultBrowser() }
            }
        } else {
            Text("既定ブラウザに未設定")
            Button("既定のブラウザにする") {
                Task { await settings.makeDefaultBrowser() }
            }
        }

        Divider()

        Picker("転送先ブラウザ", selection: Binding(
            get: { settings.effectiveFallback },
            set: { if let url = $0 { settings.setFallback(url) } }
        )) {
            ForEach(settings.installedBrowsers, id: \.self) { app in
                Text(FileManager.default.displayName(atPath: app.path)).tag(Optional(app))
            }
        }

        Button("Dropbox にログイン…") { WebResolver.shared.showLogin() }

        Text("⌥ を押しながらクリックでブラウザで開く")

        Divider()

        Toggle("ログイン時に起動", isOn: Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.set($0) }
        ))

        Button("終了") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
