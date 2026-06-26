import SwiftUI

@MainActor @Observable
final class ViewerState {
    var images: [ImageItem] = []
    var currentIndex: Int = 0
    var statusMessage: String = ""

    var currentImage: ImageItem? {
        guard currentIndex >= 0, currentIndex < images.count else { return nil }
        return images[currentIndex]
    }

    func openFile(url: URL) {
        let folderURL = url.deletingLastPathComponent()
        let fm = FileManager.default
        let items: [ImageItem]
        do {
            let contents = try fm.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            items = contents
                .filter { SupportedFormats.isSupported($0) }
                .map { ImageItem(url: $0) }
                .sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        } catch {
            items = [ImageItem(url: url)]
        }

        images = items
        currentIndex = items.firstIndex(where: { $0.url == url }) ?? 0
        updateStatus()
    }

    func nextImage() {
        guard currentIndex < images.count - 1 else {
            statusMessage = "已是最后一张"
            return
        }
        currentIndex += 1
        updateStatus()
    }

    func previousImage() {
        guard currentIndex > 0 else {
            statusMessage = "已是第一张"
            return
        }
        currentIndex -= 1
        updateStatus()
    }

    private func updateStatus() {
        guard !images.isEmpty else { return }
        statusMessage = "第 \(currentIndex + 1) / \(images.count) 张"
    }
}
