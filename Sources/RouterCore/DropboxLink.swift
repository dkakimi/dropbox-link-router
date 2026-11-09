import Foundation

/// Dropbox の URL を分類した結果。
public enum DropboxLink: Equatable, Sendable {
    /// ファイル名が URL から分かる共有リンク
    case file(name: String)
    /// 名前が URL に含まれないフォルダの共有リンク
    case folder
    /// dropbox.com だが共有リンクではない（ログイン画面など）
    case other

    /// Dropbox の URL でなければ nil を返す。
    public static func parse(_ url: URL) -> DropboxLink? {
        guard let host = url.host?.lowercased(),
              host == "dropbox.com" || host == "www.dropbox.com"
        else { return nil }

        // pathComponents はパーセントデコード済み
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let first = parts.first else { return .other }

        switch first {
        case "scl":
            // /scl/fi/<id>/<filename>
            if parts.count >= 4, parts[1] == "fi" {
                return .file(name: parts[3])
            }
            // /scl/fo/<id>/<hash>?preview=<filename>  (フォルダ内のファイルをプレビュー)
            if parts.count >= 2, parts[1] == "fo" {
                if let preview = queryValue(url, "preview"), !preview.isEmpty {
                    return .file(name: preview)
                }
                return .folder
            }
            return .other
        case "s":
            // 旧形式 /s/<id>/<filename>
            if parts.count >= 3 { return .file(name: parts[2]) }
            return .other
        case "sh":
            // 旧形式のフォルダリンク /sh/<id>/<hash>
            if let preview = queryValue(url, "preview"), !preview.isEmpty {
                return .file(name: preview)
            }
            return .folder
        default:
            return .other
        }
    }

    private static func queryValue(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == name }?.value
    }
}
