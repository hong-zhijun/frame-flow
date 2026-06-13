import SwiftUI

struct ArchiveItem: Identifiable {
    let id = UUID()
    let targetURL: URL
    let starFilter: Int
    let imageCount: Int
}

struct ThumbnailGridView: View {
    @Environment(AppState.self) private var appState
    @State private var archiveItem: ArchiveItem?
    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            starFilterBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(appState.filteredImages.enumerated()), id: \.element.id) { index, item in
                        ThumbnailCell(item: item)
                            .onTapGesture {
                                appState.selectImage(at: index)
                            }
                    }
                }
                .padding(12)
            }
        }
        .sheet(item: $archiveItem) { item in
            ArchiveConfirmView(
                targetURL: item.targetURL,
                starFilter: item.starFilter,
                imageCount: item.imageCount
            ) { confirmedURL in
                archiveItem = nil
                Task { await performArchive(to: confirmedURL) }
            }
        }
    }

    private func performArchive(to targetURL: URL) async {
        let fm = FileManager.default
        let images = appState.filteredImages

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
        return HStack(spacing: 8) {
            Text("星级")
                .font(.caption)
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
                    .frame(height: 14)

                Text("格式")
                    .font(.caption)
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
                        starFilter: appState.starFilter,
                        imageCount: appState.filteredImages.count
                    )
                } label: {
                    Label("归档", systemImage: "archivebox")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text("\(appState.filteredImages.count) / \(appState.images.count) 张")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatFilterButton(label: String, category: ImageItem.FormatCategory?) -> some View {
        let isActive = appState.formatFilter == category
        return Button {
            appState.formatFilter = category
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(appState.starFilter == value ? Color.accentColor.opacity(0.2) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(appState.starFilter == value ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
