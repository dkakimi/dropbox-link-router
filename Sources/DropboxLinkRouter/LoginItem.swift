import ServiceManagement

/// ログイン時の自動起動（システム設定 > 一般 > ログイン項目 に登録される）。
@MainActor
final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    @Published private(set) var isEnabled = false

    private init() {
        // 初回起動時は自動で ON にする
        let key = "didSetupLoginItem"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            set(true)
        }
        refresh()
    }

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("login item \(enabled ? "register" : "unregister") failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        log.notice("login item status=\(status.rawValue)")
        isEnabled = status == .enabled
    }
}
