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
    var selectedFolderID: UUID?

    let folderScanner = FolderScanner()
    let imageLoader = ImageLoader()

    func openFolder(_ url: URL, includeSubfolders: Bool = true) async {
        isLoading = true
        statusMessage = "正在扫描文件夹..."

        let node = await folderScanner.scan(url: url, includeSubfolders: includeSubfolders)
        currentFolder = node
        selectedFolderID = node.id
        images = collectImages(from: node)
        folderHistory.add(url)

        isLoading = false
        statusMessage = "共 \(images.count) 张图片"
    }

    func selectImage(at index: Int) {
        guard index >= 0, index < images.count else { return }
        currentIndex = index
        selectedImage = images[index]
        isViewerActive = true
    }

    func nextImage() {
        guard currentIndex < images.count - 1 else {
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
