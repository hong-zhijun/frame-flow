import SwiftUI

@main
struct FrameFlowApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(appState)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
    }
}

@MainActor @Observable
final class AppState {
    var folderHistory = FolderHistory()
    var currentFolder: FolderNode?
    var images: [ImageItem] = []
    var selectedImage: ImageItem?
    var isViewerActive = false
    var currentIndex: Int = 0
    var isLoading = false
    var statusMessage: String = ""
    var selectedFolderURL: URL?
    var starFilter: Int = 0
    var formatFilter: ImageItem.FormatCategory?
    var isSheetPresented = false
    var toastMessage: String?

    let folderScanner = FolderScanner()
    let imageLoader = ImageLoader()
    let starRatingStore = StarRatingStore()

    var availableFormats: [ImageItem.FormatCategory] {
        let categories = Set(images.map(\.formatCategory))
        return ImageItem.FormatCategory.allCases.filter { categories.contains($0) }
    }

    var availableStarRatings: [Int] {
        let ratings = Set(images.map { starRatingStore.rating(for: $0.url) })
        return (0...5).filter { ratings.contains($0) }.sorted()
    }

    var filteredImages: [ImageItem] {
        var result = images
        if starFilter == -1 {
            result = result.filter { starRatingStore.rating(for: $0.url) == 0 }
        } else if starFilter > 0 {
            result = result.filter { starRatingStore.rating(for: $0.url) == starFilter }
        }
        if let formatFilter {
            result = result.filter { $0.formatCategory == formatFilter }
        }
        return result
    }

    func openFolder(_ url: URL, includeSubfolders: Bool = true) async {
        isLoading = true
        statusMessage = "正在扫描文件夹..."

        let node = await folderScanner.scan(url: url, includeSubfolders: includeSubfolders)
        currentFolder = node
        selectedFolderURL = node.url
        images = collectImages(from: node)
        folderHistory.add(url)
        starFilter = 0
        formatFilter = nil
        starRatingStore.cleanupStaleEntries(in: url)

        isLoading = false
        statusMessage = "共 \(images.count) 张图片"
    }

    func refreshFolder(_ node: FolderNode) async {
        isLoading = true
        statusMessage = "正在刷新..."
        let refreshed = await folderScanner.scan(url: node.url, includeSubfolders: true)
        if let current = currentFolder {
            currentFolder = replaceNode(in: current, target: node.id, with: refreshed)
        }
        selectedFolderURL = refreshed.url
        images = collectImages(from: refreshed)
        starFilter = 0
        formatFilter = nil
        isViewerActive = false
        selectedImage = nil
        isLoading = false
        statusMessage = "共 \(images.count) 张图片"
    }

    private func replaceNode(in tree: FolderNode, target: UUID, with replacement: FolderNode) -> FolderNode {
        if tree.id == target { return replacement }
        var node = tree
        node.children = tree.children.map { replaceNode(in: $0, target: target, with: replacement) }
        return node
    }

    func selectImage(at index: Int) {
        let list = filteredImages
        guard index >= 0, index < list.count else { return }
        currentIndex = index
        selectedImage = list[index]
        isViewerActive = true
    }

    func nextImage() {
        guard currentIndex < filteredImages.count - 1 else {
            statusMessage = "已是最后一张"
            return
        }
        selectImage(at: currentIndex + 1)
    }

    func previousImage() {
        guard currentIndex > 0 else {
            statusMessage = "已是第一张"
            return
        }
        selectImage(at: currentIndex - 1)
    }

    func exitViewer() {
        isViewerActive = false
        selectedImage = nil
    }

    private func collectImages(from node: FolderNode) -> [ImageItem] {
        var result = node.images
        for child in node.children {
            result.append(contentsOf: collectImages(from: child))
        }
        return result.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
    }
}
