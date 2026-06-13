import SwiftUI

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var pendingFolderURL: URL?
    @State private var showSubfolderPrompt = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            importFolder()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("导入文件夹")
                    }
                }
        } detail: {
            if appState.isViewerActive, let image = appState.selectedImage {
                ImageViewerView(item: image)
            } else if appState.currentFolder != nil {
                ThumbnailGridView()
            } else {
                emptyState
            }
        }
        .overlay(alignment: .bottom) {
            if !appState.statusMessage.isEmpty, !appState.isLoading {
                StatusBarView(message: appState.statusMessage)
            }
        }
        .overlay {
            if appState.isLoading {
                LoadingOverlay(message: appState.statusMessage)
            }
        }
        .toast(message: Binding(get: { appState.toastMessage }, set: { appState.toastMessage = $0 }))
        .focusable()
        .onKeyPress(phases: .down) { press in
            guard appState.isViewerActive, !appState.isSheetPresented else { return .ignored }
            switch press.key {
            case .rightArrow:
                appState.nextImage()
                return .handled
            case .leftArrow:
                appState.previousImage()
                return .handled
            case .escape:
                appState.exitViewer()
                return .handled
            case _ where "12345".contains(press.characters):
                if let digit = Int(press.characters), let selected = appState.selectedImage {
                    let current = appState.starRatingStore.rating(for: selected.url)
                    appState.starRatingStore.setRating(current == digit ? 0 : digit, for: selected.url)
                    let newRating = appState.starRatingStore.rating(for: selected.url)
                    appState.statusMessage = newRating > 0 ? "已标记 \(newRating) 星" : "已取消标记"
                }
                return .handled
            default:
                return .ignored
            }
        }
        .alert("导入子文件夹", isPresented: $showSubfolderPrompt) {
            Button("包含子文件夹") {
                if let url = pendingFolderURL {
                    Task { await appState.openFolder(url, includeSubfolders: true) }
                }
            }
            Button("仅当前文件夹") {
                if let url = pendingFolderURL {
                    Task { await appState.openFolder(url, includeSubfolders: false) }
                }
            }
            Button("取消", role: .cancel) {
                pendingFolderURL = nil
            }
        } message: {
            if let url = pendingFolderURL {
                Text("是否同时导入「\(url.lastPathComponent)」中的子文件夹？")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

            Text("FrameFlow")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("导入文件夹，开始浏览和管理你的照片")
                .font(.body)
                .foregroundStyle(.secondary)

            Button("导入文件夹") {
                importFolder()
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func importFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择要导入的图片文件夹"
        panel.prompt = "导入"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let hasSubfolders = checkForSubfolders(url)
        if hasSubfolders {
            pendingFolderURL = url
            showSubfolderPrompt = true
        } else {
            Task { await appState.openFolder(url, includeSubfolders: false) }
        }
    }

    private func checkForSubfolders(_ url: URL) -> Bool {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        return contents.contains { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }
}

struct StatusBarView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 8)
    }
}

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(32)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .allowsHitTesting(false)
    }
}
