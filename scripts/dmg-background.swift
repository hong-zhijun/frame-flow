#!/usr/bin/swift
//
// 生成 DMG 安装背景图：带"拖到 Applications 安装"箭头引导
//
// 用法: swift dmg-background.swift <output.png> [width] [height]
//

import AppKit
import CoreGraphics
import CoreText

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("用法: swift dmg-background.swift <output.png> [width] [height]\n", stderr)
    exit(1)
}

let outputPath = args[1]
let width: CGFloat = args.count > 2 ? CGFloat(Int(args[2]) ?? 660) : 660
let height: CGFloat = args.count > 3 ? CGFloat(Int(args[3]) ?? 440) : 440

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(width),
    height: Int(height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("ERROR: 无法创建 CGContext\n", stderr)
    exit(1)
}

// 背景：柔和渐变（浅灰到白）
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
    ] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])

// 箭头参数
let centerY = height * 0.48
let arrowStartX = width * 0.38
let arrowEndX = width * 0.62
let arrowColor = CGColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 0.6)
let lineWidth: CGFloat = 2.5
let headLength: CGFloat = 14.0
let headWidth: CGFloat = 8.0

// 画箭头线
ctx.setStrokeColor(arrowColor)
ctx.setLineWidth(lineWidth)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: arrowStartX, y: centerY))
ctx.addLine(to: CGPoint(x: arrowEndX - headLength * 0.5, y: centerY))
ctx.strokePath()

// 画箭头头
ctx.setFillColor(arrowColor)
ctx.move(to: CGPoint(x: arrowEndX, y: centerY))
ctx.addLine(to: CGPoint(x: arrowEndX - headLength, y: centerY + headWidth))
ctx.addLine(to: CGPoint(x: arrowEndX - headLength, y: centerY - headWidth))
ctx.closePath()
ctx.fillPath()

// 底部提示文字（两行）
let hintColor = CGColor(red: 0.42, green: 0.42, blue: 0.45, alpha: 0.9)
let hintFont = CTFontCreateWithName("PingFangSC-Regular" as CFString, 13.5, nil)

let lines: [(String, CGFloat)] = [
    ("① 拖入右侧 Applications 文件夹完成安装", height * 0.22),
    ("② 首次打开请右键点击应用，选择「打开」", height * 0.14),
]

for (text, y) in lines {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: hintFont,
        .foregroundColor: NSColor(cgColor: hintColor) ?? NSColor.gray,
    ]
    let attrStr = NSAttributedString(string: text, attributes: attrs)
    let ctLine = CTLineCreateWithAttributedString(attrStr)
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    let lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, &ascent, &descent, nil))
    ctx.saveGState()
    ctx.textPosition = CGPoint(x: (width - lineWidth) / 2, y: y)
    CTLineDraw(ctLine, ctx)
    ctx.restoreGState()
}

// 导出 PNG
guard let cgImage = ctx.makeImage() else {
    fputs("ERROR: 无法生成图像\n", stderr)
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    fputs("ERROR: 无法创建 PNG 写入器\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(dest, cgImage, nil)
guard CGImageDestinationFinalize(dest) else {
    fputs("ERROR: PNG 写入失败\n", stderr)
    exit(1)
}
print("背景图已生成: \(outputPath) (\(Int(width))x\(Int(height)))")
