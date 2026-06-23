import SwiftUI

struct ArchiveItem: Identifiable {
    let id = UUID()
    let targetURL: URL
    let description: String
    let images: [ImageItem]
    var imageCount: Int { images.count }
}

private struct CellFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private let gridCoordinateSpace = "frameflow.grid"

struct ThumbnailGridView: View {
    @Environment(AppState.self) private var appState
    @State private var archiveItem: ArchiveItem?
    @State private var showBatchFrameExport = false
    @State private var cellFrames: [UUID: CGRect] = [:]
    @State private var dragRect: CGRect?
    @State private var dragStartSelection: Set<UUID> = []
    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            starFilterBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.bar)

            if !appState.selectedImageIDs.isEmpty {
                Divider()
                selectionActionBar
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.08))
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(Array(appState.filteredImages.enumerated()), id: \.element.id) { index, item in
                                ThumbnailCell(item: item)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: CellFramesPreferenceKey.self,
                                                value: [item.id: geo.frame(in: .named(gridCoordinateSpace))]
                                            )
                                        }
                                    )
                                    .onTapGesture {
                                        handleCellTap(index: index, item: item)
                                    }
                            }
                        }
                        .padding(12)

                        if let rect = dragRect {
                            Rectangle()
                                .stroke(Color.accentColor, lineWidth: 1)
                                .background(Color.accentColor.opacity(0.15))
                                .frame(width: rect.width, height: rect.height)
                                .offset(x: rect.minX, y: rect.minY)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .coordinateSpace(name: gridCoordinateSpace)
                    .onPreferenceChange(CellFramesPreferenceKey.self) { frames in
                        cellFrames = frames
                    }
                    .gesture(rubberBandGesture)
                }
                .onAppear {
                    guard let id = appState.selectedImage?.id,
                          appState.filteredImages.contains(where: { $0.id == id }) else { return }
                    DispatchQueue.main.async {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .sheet(item: $archiveItem) { item in
            ArchiveConfirmView(
                targetURL: item.targetURL,
                description: item.description,
                imageCount: item.imageCount
            ) { confirmedURL in
                let images = item.images
                archiveItem = nil
                Task { await performArchive(images: images, to: confirmedURL) }
            }
        }
        .sheet(isPresented: $showBatchFrameExport) {
            FrameExportView(items: appState.selectedImages)
                .interactiveDismissDisabled()
        }
        .onChange(of: showBatchFrameExport) { _, newValue in
            appState.isSheetPresented = newValue
        }
    }

    private func handleCellTap(index: Int, item: ImageItem) {
        if appState.selectedImageIDs.isEmpty {
            appState.selectImage(at: index)
        } else {
            appState.toggleSelection(item.id)
        }
    }

    private var rubberBandGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(gridCoordinateSpace))
            .onChanged { value in
                if dragRect == nil {
                    dragStartSelection = appState.selectedImageIDs
                }
                let rect = CGRect(
                    x: min(value.startLocation.x, value.location.x),
                    y: min(value.startLocation.y, value.location.y),
                    width: abs(value.location.x - value.startLocation.x),
                    height: abs(value.location.y - value.startLocation.y)
                )
                dragRect = rect
                let inside = cellFrames.compactMap { (id, frame) in
                    frame.intersects(rect) ? id : nil
                }
                appState.selectedImageIDs = dragStartSelection.union(inside)
            }
            .onEnded { _ in
                dragRect = nil
                dragStartSelection = []
            }
    }

    private func performArchive(images: [ImageItem], to targetURL: URL) async {
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: targetURL, withIntermediateDirectories: true)
        } catch {
            appState.toastMessage = "创建文件夹失败：\(error.localizedDescription)"
            return
        }

        var movedCount = 0
        for image in images {
            let destURL = uniqueURL(for: image.url.lastPathComponent, in: targetURL)
            do {
                try fm.moveItem(at: image.url, to: destURL)
                appState.starRatingStore.setRating(0, for: image.url)
                movedCount += 1
            } catch {
                continue
            }
        }

        appState.toastMessage = "已归档 \(movedCount) 张图片到「\(targetURL.lastPathComponent)」"
        appState.starFilter = 0
        appState.clearSelection()
        if let folder = appState.currentFolder {
            await appState.refreshFolder(folder)
        }
    }

    private func uniqueURL(for filename: String, in directory: URL) -> URL {
        let fm = FileManager.default
        var url = directory.appendingPathComponent(filename)
        guard fm.fileExists(atPath: url.path(percentEncoded: false)) else { return url }

        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 1
        repeat {
            url = directory.appendingPathComponent("\(name)_\(counter).\(ext)")
            counter += 1
        } while fm.fileExists(atPath: url.path(percentEncoded: false))
        return url
    }

    private var starFilterBar: some View {
        @Bindable var state = appState
        return HStack(spacing: 10) {
            Text("星级")
                .font(.callout)
                .foregroundStyle(.secondary)

            starFilterButton(label: "全部", value: 0)

            let available = appState.availableStarRatings
            if available.contains(0) {
                starFilterButton(label: "无星", value: -1)
            }
            ForEach(available.filter { $0 > 0 }, id: \.self) { star in
                starFilterButton(
                    label: "\(star)星",
                    value: star,
                    icon: "star.fill"
                )
            }

            if appState.availableFormats.count > 1 {
                Divider()
                    .frame(height: 18)

                Text("格式")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                formatFilterButton(label: "全部", category: nil)

                ForEach(appState.availableFormats, id: \.self) { category in
                    formatFilterButton(label: category.label, category: category)
                }
            }

            Spacer()

            if appState.starFilter > 0 {
                Button {
                    guard let folder = appState.currentFolder else { return }
                    archiveItem = ArchiveItem(
                        targetURL: folder.url.appendingPathComponent("归档-\(appState.starFilter)星"),
                        description: "\(appState.starFilter)星图片",
                        images: appState.filteredImages
                    )
                } label: {
                    Label("归档", systemImage: "archivebox")
                        .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            Text("\(appState.filteredImages.count) / \(appState.images.count) 张")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var selectionActionBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(Color.accentColor)

            Text("已选 \(appState.selectedImageIDs.count) 张")
                .font(.callout)
                .fontWeight(.medium)

            Button("全选") {
                appState.selectAllVisible()
            }
            .buttonStyle(.borderless)
            .font(.callout)

            Button("清除") {
                appState.clearSelection()
            }
            .buttonStyle(.borderless)
            .font(.callout)

            Spacer()

            Button {
                guard let folder = appState.currentFolder else { return }
                archiveItem = ArchiveItem(
                    targetURL: folder.url.appendingPathComponent("批量归档"),
                    description: "选中的图片",
                    images: appState.selectedImages
                )
            } label: {
                Label("批量归档", systemImage: "archivebox")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button {
                showBatchFrameExport = true
            } label: {
                Label("批量边框水印", systemImage: "square.and.arrow.up")
                    .font(.callout)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    private func formatFilterButton(label: String, category: ImageItem.FormatCategory?) -> some View {
        let isActive = appState.formatFilter == category
        return Button {
            appState.formatFilter = category
        } label: {
            Text(label)
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(isActive ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func starFilterButton(label: String, value: Int, icon: String? = nil) -> some View {
        Button {
            appState.starFilter = value
            appState.statusMessage = value == 0
                ? "共 \(appState.images.count) 张图片"
                : "\(value)星: \(appState.filteredImages.count) 张"
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                }
                Text(label)
                    .font(.callout)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(appState.starFilter == value ? Color.accentColor.opacity(0.2) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(appState.starFilter == value ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
