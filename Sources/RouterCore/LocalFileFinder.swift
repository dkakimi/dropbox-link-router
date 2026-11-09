import Foundation

/// ローカルの Dropbox フォルダからファイル名で検索する。
public struct LocalFileFinder: Sendable {
    public var roots: [URL]

    public init(roots: [URL] = LocalFileFinder.dropboxRoots()) {
        self.roots = roots
    }

    /// ~/Library/CloudStorage/Dropbox* と旧来の ~/Dropbox* を探す。
    public static func dropboxRoots() -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let candidates = [home.appendingPathComponent("Library/CloudStorage"), home]
        return candidates.flatMap { dir -> [URL] in
            let items = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            return items.filter {
                $0.lastPathComponent.hasPrefix("Dropbox")
                    && (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
        }
    }

    /// Spotlight で探し、見つからなければディレクトリを走査する。
    public func find(named name: String, timeout: TimeInterval = 10) async -> [URL] {
        guard !roots.isEmpty else { return [] }
        let spotlight = await SpotlightSearch.run(name: name, scopes: roots, timeout: 3)
        if !spotlight.isEmpty { return spotlight }
        let roots = self.roots
        return await Task.detached(priority: .userInitiated) {
            LocalFileFinder.walk(name: name, roots: roots, deadline: Date().addingTimeInterval(timeout))
        }.value
    }

    /// dropbox.com/home/A/B の URL をローカルの <root>/A/B に変換する（存在するものだけ）。
    public static func localPath(forHomeURL url: URL, roots: [URL]) -> URL? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.first == "home", parts.count > 1 else { return nil }
        var rel = Array(parts.dropFirst())
        // ファイルは /home/<dir>?preview=<file> の形で開かれる
        if let preview = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "preview" })?.value, !preview.isEmpty,
           rel.last != preview {
            rel.append(preview)
        }
        for root in roots {
            let candidate = rel.reduce(root) { $0.appendingPathComponent($1) }
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    /// 同名候補が複数あるとき、パンくずリストと末尾が最も長く一致するものに絞る。
    public static func rank(_ matches: [URL], breadcrumb: [String]) -> [URL] {
        guard matches.count > 1, !breadcrumb.isEmpty else { return matches }
        let crumbs = breadcrumb.map(normalize).reversed()
        func score(_ url: URL) -> Int {
            var s = 0
            for (c, p) in zip(crumbs, url.pathComponents.map(normalize).reversed()) {
                guard c == p else { break }
                s += 1
            }
            return s
        }
        let best = matches.map(score).max() ?? 0
        return best == 0 ? matches : matches.filter { score($0) == best }
    }

    /// macOS のファイル名は NFD のことがあるので NFC に揃えて比較する。
    static func normalize(_ s: String) -> String {
        s.precomposedStringWithCanonicalMapping
    }

    static func walk(name: String, roots: [URL], deadline: Date) -> [URL] {
        let target = normalize(name)
        var results: [URL] = []
        for root in roots {
            guard let e = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in e {
                if Date() > deadline { return results }
                if normalize(url.lastPathComponent) == target {
                    results.append(url)
                }
            }
        }
        return results
    }
}

/// NSMetadataQuery はメインスレッドの RunLoop が必要なので MainActor で実行する。
@MainActor
enum SpotlightSearch {
    static func run(name: String, scopes: [URL], timeout: TimeInterval) async -> [URL] {
        await withCheckedContinuation { (cont: CheckedContinuation<[URL], Never>) in
            let query = NSMetadataQuery()
            let nfc = name.precomposedStringWithCanonicalMapping
            let nfd = name.decomposedStringWithCanonicalMapping
            query.predicate = NSPredicate(
                format: "%K == %@ OR %K == %@",
                NSMetadataItemFSNameKey, nfc, NSMetadataItemFSNameKey, nfd
            )
            query.searchScopes = scopes

            var finished = false
            var observer: NSObjectProtocol?
            let finish = {
                guard !finished else { return }
                finished = true
                query.stop()
                if let observer { NotificationCenter.default.removeObserver(observer) }
                let urls = (query.results as? [NSMetadataItem] ?? []).compactMap {
                    ($0.value(forAttribute: NSMetadataItemPathKey) as? String).map(URL.init(fileURLWithPath:))
                }
                cont.resume(returning: urls)
            }
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
            ) { _ in MainActor.assumeIsolated { finish() } }

            if !query.start() { finish(); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { finish() }
        }
    }
}
