import AppKit
import CoreGraphics
import CoreText

struct FrameStyle {
    var backgroundColor: NSColor = .white
    var textColor: NSColor = .black
    var secondaryTextColor: NSColor = .darkGray
    var barHeight: CGFloat = 0.08
    var padding: CGFloat = 0.02
    var borderEnabled: Bool = true
    var borderWidth: CGFloat = 1
    var logoScale: CGFloat = 1.0
}

enum FrameRenderer {
    static func render(
        image: NSImage,
        exif: EXIFData,
        style: FrameStyle = FrameStyle(),
        logoImage: NSImage? = nil,
        rightMainText: String? = nil
    ) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let barHeight = max(imageWidth, imageHeight) * style.barHeight
        let sidePadding = imageWidth * style.padding
        let borderWidth = style.borderEnabled ? style.borderWidth * (imageWidth / 1000.0) : 0

        let canvasWidth = imageWidth + borderWidth * 2
        let canvasHeight = imageHeight + barHeight + borderWidth * 3

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(canvasWidth),
            height: Int(canvasHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(style.backgroundColor.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

        let imageRect = CGRect(x: borderWidth, y: barHeight + borderWidth * 2, width: imageWidth, height: imageHeight)
        ctx.draw(cgImage, in: imageRect)

        if style.borderEnabled {
            ctx.setStrokeColor(NSColor.lightGray.withAlphaComponent(0.3).cgColor)
            ctx.setLineWidth(borderWidth)
            ctx.stroke(imageRect.insetBy(dx: -borderWidth / 2, dy: -borderWidth / 2))
        }

        let barRect = CGRect(x: borderWidth, y: borderWidth, width: imageWidth, height: barHeight)
        drawBarContent(ctx: ctx, rect: barRect, exif: exif, style: style, padding: sidePadding, logoImage: logoImage, rightMainText: rightMainText)

        guard let result = ctx.makeImage() else { return nil }
        return NSImage(cgImage: result, size: NSSize(width: canvasWidth, height: canvasHeight))
    }

    private static func drawBarContent(
        ctx: CGContext,
        rect: CGRect,
        exif: EXIFData,
        style: FrameStyle,
        padding: CGFloat,
        logoImage: NSImage?,
        rightMainText: String? = nil
    ) {
        let primaryFontSize = rect.height * 0.28
        let secondaryFontSize = rect.height * 0.20

        let primaryFont = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, primaryFontSize, nil)
        let secondaryFont = CTFontCreateWithName("HelveticaNeue" as CFString, secondaryFontSize, nil)

        let primaryAttrs: [NSAttributedString.Key: Any] = [
            .font: primaryFont,
            .foregroundColor: style.textColor
        ]
        let secondaryAttrs: [NSAttributedString.Key: Any] = [
            .font: secondaryFont,
            .foregroundColor: style.secondaryTextColor
        ]

        var leftX = rect.minX + padding

        if let logo = logoImage, let logoCG = logo.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let logoHeight = rect.height * 0.5 * style.logoScale
            let logoWidth = logoHeight * (CGFloat(logoCG.width) / CGFloat(logoCG.height))
            let logoY = rect.midY - logoHeight / 2
            ctx.draw(logoCG, in: CGRect(x: leftX, y: logoY, width: logoWidth, height: logoHeight))
            leftX += logoWidth + padding * 0.8

            let separatorX = leftX
            ctx.setStrokeColor(NSColor.lightGray.cgColor)
            ctx.setLineWidth(rect.height * 0.02)
            ctx.move(to: CGPoint(x: separatorX, y: rect.minY + rect.height * 0.2))
            ctx.addLine(to: CGPoint(x: separatorX, y: rect.minY + rect.height * 0.8))
            ctx.strokePath()
            leftX += padding * 0.8
        } else if !exif.cameraMake.isEmpty {
            let makeStr = NSAttributedString(string: exif.cameraMake, attributes: primaryAttrs)
            let makeLine = CTLineCreateWithAttributedString(makeStr)
            let makeWidth = CTLineGetTypographicBounds(makeLine, nil, nil, nil)
            let makeY = rect.midY - primaryFontSize * 0.35
            ctx.textPosition = CGPoint(x: leftX, y: makeY)
            CTLineDraw(makeLine, ctx)
            leftX += CGFloat(makeWidth) + padding * 0.8

            let separatorX = leftX
            ctx.setStrokeColor(NSColor.lightGray.cgColor)
            ctx.setLineWidth(rect.height * 0.02)
            ctx.move(to: CGPoint(x: separatorX, y: rect.minY + rect.height * 0.2))
            ctx.addLine(to: CGPoint(x: separatorX, y: rect.minY + rect.height * 0.8))
            ctx.strokePath()
            leftX += padding * 0.8
        }

        let modelStr = exif.cameraModel.isEmpty ? "" : exif.cameraModel
        let lensStr = exif.lensModel

        if !modelStr.isEmpty {
            let modelAttr = NSAttributedString(string: modelStr, attributes: primaryAttrs)
            let modelLine = CTLineCreateWithAttributedString(modelAttr)
            let topY = rect.midY + (lensStr.isEmpty ? -primaryFontSize * 0.35 : secondaryFontSize * 0.1)
            ctx.textPosition = CGPoint(x: leftX, y: topY)
            CTLineDraw(modelLine, ctx)
        }

        if !lensStr.isEmpty {
            let lensAttr = NSAttributedString(string: lensStr, attributes: secondaryAttrs)
            let lensLine = CTLineCreateWithAttributedString(lensAttr)
            let bottomY = rect.midY - primaryFontSize * 0.6 - secondaryFontSize * 0.2
            ctx.textPosition = CGPoint(x: leftX, y: bottomY)
            CTLineDraw(lensLine, ctx)
        }

        let rightX = rect.maxX - padding
        let paramText = rightMainText ?? exif.parameterLine
        if !paramText.isEmpty {
            let paramAttr = NSAttributedString(string: paramText, attributes: primaryAttrs)
            let paramLine = CTLineCreateWithAttributedString(paramAttr)
            let paramWidth = CTLineGetTypographicBounds(paramLine, nil, nil, nil)

            let dateOrLocation = [exif.author, exif.dateTaken, exif.location].first { !$0.isEmpty } ?? ""
            if !dateOrLocation.isEmpty {
                let topY = rect.midY + secondaryFontSize * 0.1
                ctx.textPosition = CGPoint(x: rightX - CGFloat(paramWidth), y: topY)
                CTLineDraw(paramLine, ctx)

                let subAttr = NSAttributedString(string: dateOrLocation, attributes: secondaryAttrs)
                let subLine = CTLineCreateWithAttributedString(subAttr)
                let subWidth = CTLineGetTypographicBounds(subLine, nil, nil, nil)
                let bottomY = rect.midY - primaryFontSize * 0.6 - secondaryFontSize * 0.2
                ctx.textPosition = CGPoint(x: rightX - CGFloat(subWidth), y: bottomY)
                CTLineDraw(subLine, ctx)
            } else {
                let centerY = rect.midY - primaryFontSize * 0.35
                ctx.textPosition = CGPoint(x: rightX - CGFloat(paramWidth), y: centerY)
                CTLineDraw(paramLine, ctx)
            }
        }
    }

    static func exportAsJPEG(_ image: NSImage, to url: URL, quality: CGFloat = 0.95) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            return false
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }
}
