import AppKit
import ImageIO

actor ImageLoader {
    private var thumbnailCache: [URL: NSImage] = [:]
    private var inflight: [URL: Task<NSImage?, Never>] = [:]

    /// 默认 maxSize=320 对齐 140pt 缩略格 @ 2× Retina，并留少量余量。
    /// 解码工作放进 detached task 在后台并行，actor 只负责 cache / inflight 簿记，
    /// 避免 actor 隔离把所有缩略图串行化（之前 40 张要顺序解码，CPU 多核闲置）。
    func loadThumbnail(for item: ImageItem, maxSize: CGFloat = 320) async -> NSImage? {
        if let cached = thumbnailCache[item.url] {
            return cached
        }
        if let task = inflight[item.url] {
            return await task.value
        }

        let url = item.url
        let task = Task<NSImage?, Never>.detached(priority: .userInitiated) {
            Self.decodeThumbnail(at: url, maxSize: maxSize)
        }
        inflight[item.url] = task

        let result = await task.value
        inflight.removeValue(forKey: item.url)
        if let result {
            thumbnailCache[item.url] = result
        }
        return result
    }

    func clearCache() {
        thumbnailCache.removeAll()
    }

    nonisolated private static func decodeThumbnail(at url: URL, maxSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxSize,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            // 让 CGImage 立即解码并缓存位图，避免 SwiftUI 首次绘制时再触发同步解码引起卡顿
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
