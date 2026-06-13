import AppKit
import CoreImage
import ImageIO

enum ImageLoadError: Error, LocalizedError {
    case sourceCreationFailed
    case decodeFailed
    case unsupportedFormat(String)

    var errorDescription: String? {
        switch self {
        case .sourceCreationFailed: "无法读取图片文件"
        case .decodeFailed: "图片解码失败"
        case .unsupportedFormat(let ext): "不支持的格式: \(ext)"
        }
    }
}

actor RAWProcessor {
    private lazy var ciContext = CIContext(options: [.cacheIntermediates: true])

    func loadImage(url: URL) throws -> NSImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageLoadError.sourceCreationFailed
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageLoadError.decodeFailed
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    func decodeRAW(url: URL) throws -> NSImage {
        guard let rawFilter = CIRAWFilter(imageURL: url) else {
            throw ImageLoadError.sourceCreationFailed
        }

        if rawFilter.supportedDecoderVersions.contains(.version9) {
            rawFilter.decoderVersion = .version9
        }

        guard let ciImage = rawFilter.outputImage,
              let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw ImageLoadError.decodeFailed
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }
}
