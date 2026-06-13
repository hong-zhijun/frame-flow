import AppKit
import ImageIO

actor ImageLoader {
    private var thumbnailCache: [URL: NSImage] = [:]

    func loadThumbnail(for item: ImageItem, maxSize: CGFloat = 512) -> NSImage? {
        if let cached = thumbnailCache[item.url] {
            return cached
        }

        guard let source = CGImageSourceCreateWithURL(item.url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        thumbnailCache[item.url] = image
        return image
    }

    func clearCache() {
        thumbnailCache.removeAll()
    }
}
