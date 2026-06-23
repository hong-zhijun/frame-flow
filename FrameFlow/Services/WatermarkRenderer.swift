import AppKit
import CoreGraphics
import CoreText

enum WatermarkRenderer {
    /// 在源图像上叠加水印，返回带水印的新图像。失败返回 nil。
    static func apply(image: NSImage, config: WatermarkConfig) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setAlpha(config.opacity)

        switch config.kind {
        case .text:
            drawText(ctx: ctx, config: config, canvas: CGSize(width: width, height: height))
        case .image:
            drawImage(ctx: ctx, config: config, canvas: CGSize(width: width, height: height))
        case .tiled:
            drawTiled(ctx: ctx, config: config, canvas: CGSize(width: width, height: height))
        }

        guard let output = ctx.makeImage() else { return nil }
        return NSImage(cgImage: output, size: NSSize(width: width, height: height))
    }

    // MARK: - Text

    private static func drawText(ctx: CGContext, config: WatermarkConfig, canvas: CGSize) {
        guard !config.text.isEmpty else { return }
        let line = makeTextLine(text: config.text, fontSize: textPointSize(in: canvas, config: config), color: config.textColor)
        let bounds = CTLineGetImageBounds(line, ctx)
        let size = CGSize(width: bounds.width, height: bounds.height)
        let origin = positionPoint(for: config.position, canvas: canvas, contentSize: size, margin: config.margin)
        ctx.textPosition = CGPoint(x: origin.x - bounds.origin.x, y: origin.y - bounds.origin.y)
        CTLineDraw(line, ctx)
    }

    // MARK: - Image

    private static func drawImage(ctx: CGContext, config: WatermarkConfig, canvas: CGSize) {
        guard let url = config.imageURL,
              let watermark = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        let target = imageDrawSize(watermark: watermark, canvas: canvas, scale: config.imageScale)
        let origin = positionPoint(for: config.position, canvas: canvas, contentSize: target, margin: config.margin)
        ctx.draw(watermark, in: CGRect(origin: origin, size: target))
    }

    // MARK: - Tiled

    /// 平铺策略：把"文字/图片 + 旋转角度"预渲染成一个 axis-aligned 的 CGImage 块，
    /// 然后在画布坐标系里规整地排列。不再在旋转坐标系里迭代，间距均匀、不会出现
    /// 一行左有右无的边界问题。
    private static func drawTiled(ctx: CGContext, config: WatermarkConfig, canvas: CGSize) {
        guard let tile = makeRotatedTile(config: config, canvas: canvas) else { return }
        let tileW = CGFloat(tile.width)
        let tileH = CGFloat(tile.height)
        let canvasMax = max(canvas.width, canvas.height)

        // 行间（Y）受 tileSpacing 控制；行内（X）固定 4% 小间隔避免视觉粘连。
        let xStep = tileW + canvasMax * 0.04
        let yStep = tileH + canvasMax * config.tileSpacing

        // 起点稍微往左上偏，让画布边缘也能被覆盖；隔行 stagger 半步给一点错落感
        var y = -tileH
        var rowIndex = 0
        while y < canvas.height + tileH {
            let xOffset: CGFloat = (rowIndex % 2 == 1) ? xStep / 2 : 0
            var x = -tileW + xOffset
            while x < canvas.width + tileW {
                ctx.draw(tile, in: CGRect(x: x, y: y, width: tileW, height: tileH))
                x += xStep
            }
            y += yStep
            rowIndex += 1
        }
    }

    /// 把水印内容（文字 / 图片）预渲染到一张 bitmap，并把旋转烘焙进去。
    /// 返回的 CGImage 大小等于旋转后的外包围盒（透明背景）。
    private static func makeRotatedTile(config: WatermarkConfig, canvas: CGSize) -> CGImage? {
        // 1. 确定要画的内容（image 优先于 text）和它在 axis-aligned 下的尺寸
        let watermarkCG = config.imageURL.flatMap {
            NSImage(contentsOf: $0)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }

        let contentSize: CGSize
        var line: CTLine?
        var ascent: CGFloat = 0
        var descent: CGFloat = 0

        if let watermarkCG {
            contentSize = imageDrawSize(watermark: watermarkCG, canvas: canvas, scale: config.imageScale)
        } else if !config.text.isEmpty {
            let fontSize = textPointSize(in: canvas, config: config)
            let ctLine = makeTextLine(text: config.text, fontSize: fontSize, color: config.textColor)
            let width = CTLineGetTypographicBounds(ctLine, &ascent, &descent, nil)
            line = ctLine
            contentSize = CGSize(width: ceil(width), height: ceil(ascent + descent))
        } else {
            return nil
        }

        // 2. 计算旋转后外包围盒
        let radians = config.tileRotationDegrees * .pi / 180
        let cosA = abs(cos(radians))
        let sinA = abs(sin(radians))
        let rotW = contentSize.width * cosA + contentSize.height * sinA
        let rotH = contentSize.width * sinA + contentSize.height * cosA

        // 3. 在 bitmap context 里绕中心旋转，把内容画在 (0,0)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let tileCtx = CGContext(
            data: nil,
            width: max(1, Int(ceil(rotW))),
            height: max(1, Int(ceil(rotH))),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        tileCtx.translateBy(x: rotW / 2, y: rotH / 2)
        tileCtx.rotate(by: radians)
        tileCtx.translateBy(x: -contentSize.width / 2, y: -contentSize.height / 2)

        if let watermarkCG {
            tileCtx.draw(watermarkCG, in: CGRect(origin: .zero, size: contentSize))
        } else if let line {
            tileCtx.textPosition = CGPoint(x: 0, y: descent)
            CTLineDraw(line, tileCtx)
        }

        return tileCtx.makeImage()
    }

    // MARK: - Helpers

    private static func makeTextLine(text: String, fontSize: CGFloat, color: NSColor) -> CTLine {
        let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    }

    private static func textPointSize(in canvas: CGSize, config: WatermarkConfig) -> CGFloat {
        max(canvas.width, canvas.height) * config.fontSize
    }

    private static func imageDrawSize(watermark: CGImage, canvas: CGSize, scale: CGFloat) -> CGSize {
        let targetWidth = canvas.width * scale
        let aspect = CGFloat(watermark.height) / CGFloat(watermark.width)
        return CGSize(width: targetWidth, height: targetWidth * aspect)
    }

    /// 在 CGContext 坐标系（原点左下）下计算放置点
    private static func positionPoint(for position: WatermarkConfig.Position,
                                       canvas: CGSize,
                                       contentSize: CGSize,
                                       margin: CGFloat) -> CGPoint {
        let m = min(canvas.width, canvas.height) * margin
        let x: CGFloat
        switch position.gridIndex.col {
        case 0: x = m
        case 1: x = (canvas.width - contentSize.width) / 2
        default: x = canvas.width - contentSize.width - m
        }
        let y: CGFloat
        switch position.gridIndex.row {
        case 0: y = canvas.height - contentSize.height - m   // 顶部：高 Y
        case 1: y = (canvas.height - contentSize.height) / 2
        default: y = m                                        // 底部：低 Y
        }
        return CGPoint(x: x, y: y)
    }
}
