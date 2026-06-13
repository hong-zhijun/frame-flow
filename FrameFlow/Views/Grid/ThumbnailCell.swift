import SwiftUI

struct ThumbnailCell: View {
    let item: ImageItem
    @Environment(AppState.self) private var appState
    @State private var thumbnail: NSImage?
    @State private var isLoading = true

    var body: some View {
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
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(item.filename)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 140)
        }
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
