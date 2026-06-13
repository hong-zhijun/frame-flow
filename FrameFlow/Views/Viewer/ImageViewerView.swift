import SwiftUI

struct ImageViewerView: View {
    let item: ImageItem
    @Environment(AppState.self) private var appState
    @State private var displayImage: NSImage?
    @State private var isLoading = true
    @State private var isDecodingRAW = false
    @State private var rawDecoded = false
    @State private var errorMessage: String?

    private let rawProcessor = RAWProcessor()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let displayImage {
                ZoomableImageView(image: displayImage)
            }

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在加载...")
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else if displayImage == nil, let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(errorMessage)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .overlay(alignment: .bottom) {
            viewerStatusBar
        }
        .overlay(alignment: .topLeading) {
            Button {
                appState.exitViewer()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
            .help("返回网格视图 (Esc)")
        }
        .overlay(alignment: .leading) {
            if appState.currentIndex > 0 {
                navArrow(systemName: "chevron.left") {
                    appState.previousImage()
                }
                .padding(.leading, 12)
            }
        }
        .overlay(alignment: .trailing) {
            if appState.currentIndex < appState.images.count - 1 {
                navArrow(systemName: "chevron.right") {
                    appState.nextImage()
                }
                .padding(.trailing, 12)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if item.isRAW, !isLoading {
                rawButton
                    .padding(.trailing, 16)
                    .padding(.bottom, 44)
            }
        }
        .task(id: item.id) {
            await loadImage()
        }
    }

    private var rawButton: some View {
        Group {
            if isDecodingRAW {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在解码 RAW...")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            } else if rawDecoded {
                Label("RAW 已解码", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            } else {
                Button {
                    Task { await decodeRAW() }
                } label: {
                    Label("解码 RAW", systemImage: "wand.and.rays")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var viewerStatusBar: some View {
        HStack {
            Text(item.filename)

            StarRatingView(
                rating: appState.starRatingStore.rating(for: item.url),
                size: 12
            ) { newRating in
                appState.starRatingStore.setRating(newRating, for: item.url)
            }
            .padding(.leading, 8)

            Spacer()
            Text("第 \(appState.currentIndex + 1) / \(appState.filteredImages.count) 张")
            if item.isRAW {
                Text("RAW")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.black.opacity(0.6))
    }

    private func navArrow(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(10)
                .background(.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func loadImage() async {
        isLoading = true
        errorMessage = nil
        displayImage = nil
        isDecodingRAW = false
        rawDecoded = false

        do {
            let image = try await rawProcessor.loadImage(url: item.url)
            displayImage = image
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func decodeRAW() async {
        isDecodingRAW = true
        do {
            let image = try await rawProcessor.decodeRAW(url: item.url)
            displayImage = image
            rawDecoded = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isDecodingRAW = false
    }
}
