import SwiftUI

struct ThumbnailCell: View {
    let item: ImageItem
    @Environment(AppState.self) private var appState
    @State private var thumbnail: NSImage?
    @State private var isLoading = true

    var body: some View {
        let rating = appState.starRatingStore.rating(for: item.url)
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipped()
                } else if isLoading {
                    ProgressView()
                        .frame(width: 140, height: 140)
                } else {
                    placeholderView
                }

                formatBadge
                    .padding(4)

                if rating > 0 {
                    HStack(spacing: 1) {
                        ForEach(1...rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(4)
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(item.filename)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 140)
        }
        .contextMenu(menuItems: {
            Button("在访达中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button("复制图片") {
                if let img = thumbnail {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects([img])
                }
            }
        }, preview: {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 280, height: 280)
            }
        })
        .task {
            await loadThumbnail()
        }
    }

    private var formatBadge: some View {
        Text(item.formatLabel)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(badgeColor, in: RoundedRectangle(cornerRadius: 4))
    }

    private var badgeColor: Color {
        switch item.formatCategory {
        case .raw:  .orange
        case .jpeg: .blue
        case .png:  .green
        case .heic: .purple
        case .gif:  .pink
        case .tiff: .teal
        case .other: .gray
        }
    }

    private var placeholderView: some View {
        VStack {
            Image(systemName: "photo")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text("不支持的格式")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 140, height: 140)
        .background(.quaternary)
    }

    private func loadThumbnail() async {
        let image = await appState.imageLoader.loadThumbnail(for: item)
        thumbnail = image
        isLoading = false
    }
}
