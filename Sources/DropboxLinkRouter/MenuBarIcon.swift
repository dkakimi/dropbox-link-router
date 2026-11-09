import AppKit

/// フォルダの中央に Dropbox ロゴを白抜きにしたメニューバー用テンプレート画像。
enum MenuBarIcon {
    static func make(height: CGFloat = 18) -> NSImage {
        let size = NSSize(width: height * 1.25, height: height)
        let config = NSImage.SymbolConfiguration(pointSize: height * 0.95, weight: .regular)
        guard let folder = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return NSImage(size: size) }
        let fs = folder.size
        let folderRect = NSRect(x: (size.width - fs.width) / 2, y: (size.height - fs.height) / 2,
                                width: fs.width, height: fs.height)
        let drawFolder = {
            folder.draw(in: folderRect, from: .zero, operation: .sourceOver, fraction: 1,
                        respectFlipped: true, hints: nil)
        }

        // フォルダだけを本番と同じ描き方で描いて、実際に描かれた左右の範囲を測る
        // （SF Symbols は画像の枠と見た目の形の中心が一致しない）
        let folderOnly = NSImage(size: size, flipped: true) { _ in drawFolder(); return true }
        let visible = opaqueBounds(of: folderOnly, size: size)

        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawFolder()

            // ロゴをくり抜く（フォルダ本体はタブの分だけ下寄りなので少し下げる）
            let logoHeight = folderRect.height * 0.48
            let scale = logoHeight / logoBounds.height
            let logoWidth = logoBounds.width * scale
            let center = CGPoint(x: visible.midX, y: folderRect.midY + folderRect.height * 0.14)

            ctx.saveGState()
            ctx.setBlendMode(.destinationOut)
            ctx.translateBy(x: center.x - logoWidth / 2, y: center.y - logoHeight / 2)
            ctx.scaleBy(x: scale, y: scale)
            ctx.addPath(logoPath)
            ctx.fillPath()
            ctx.restoreGState()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// 画像の不透明部分の範囲（pt 単位、左上原点）。x 方向だけ使う。
    private static func opaqueBounds(of image: NSImage, size: NSSize) -> CGRect {
        let scale: CGFloat = 8
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard w > 0, h > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return CGRect(origin: .zero, size: size) }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()

        var minX = w, maxX = -1
        for y in 0..<h {
            for x in 0..<w where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                minX = min(minX, x); maxX = max(maxX, x)
            }
        }
        guard maxX >= minX else { return CGRect(origin: .zero, size: size) }
        return CGRect(x: CGFloat(minX) / scale, y: 0,
                      width: CGFloat(maxX - minX + 1) / scale, height: size.height)
    }

    // Dropbox グリフ（42.5 x 39.4、y 下向き）
    private static let logoBounds = CGRect(x: 0, y: 0, width: 42.5, height: 39.4)

    private static let logoPath: CGPath = {
        let polygons: [[CGPoint]] = [
            // 上左
            [(12.5, 0), (0, 8.1), (8.7, 15.1), (21.3, 7.2)],
            // 上右
            [(30.1, 0), (21.3, 7.3), (33.9, 15.1), (42.5, 8.1)],
            // 中左
            [(0, 21.9), (12.5, 30.1), (21.3, 22.7), (8.7, 15.1)],
            // 中右
            [(21.3, 22.7), (30.1, 30.1), (42.5, 22.0), (33.9, 15.0)],
            // 下
            [(21.4, 24.3), (12.6, 31.6), (8.8, 29.1), (8.8, 31.9),
             (21.4, 39.4), (34, 31.9), (34, 29.1), (30.2, 31.6)],
        ].map { $0.map { CGPoint(x: $0.0, y: $0.1) } }

        let path = CGMutablePath()
        for poly in polygons { path.addLines(between: poly); path.closeSubpath() }
        return path
    }()
}
