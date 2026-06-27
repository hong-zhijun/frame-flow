import SwiftUI

struct StandaloneViewerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let initialURL: URL
    @State private var viewerState = ViewerState()
    @State private var displayImage: NSImage?
    @State private var isLoading = true
    @State private var isDecodingRAW = false
    @State private var rawDecoded = false
    @State private var errorMessage: String?
    @State private var showFrameExport = false
    @State private var showEXIF = false
    @State private var exifData: EXIFData = .empty

    private let rawProcessor = RAWProcessor()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let displayImage {
                ZoomableImageView(image: displayImage)
                    .contextMenu {
                        if let item = viewerState.currentImage {
                            Button("在访达中显示") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                            Button("复制图片") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.writeObjects([displayImage])
                            }
                        }
                    }
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
        .overlay(alignment: .leading) {
            if viewerState.currentIndex > 0 {
                navArrow(systemName: "chevron.left") {
                    viewerState.previousImage()
                }
                .padding(.leading, 12)
            }
        }
        .overlay(alignment: .trailing) {
            if viewerState.currentIndex < viewerState.images.count - 1 {
                navArrow(systemName: "chevron.right") {
                    viewerState.nextImage()
                }
                .padding(.trailing, 12)
            }
        }
        .overlay(alignment: .bottom) {
            statusBar
        }
        .overlay(alignment: .bottomTrailing) {
            actionButtons
                .padding(.trailing, 16)
                .padding(.bottom, 44)
        }
        .overlay(alignment: .trailing) {
            if showEXIF {
                exifPanel
                    .padding(.trailing, 12)
                    .padding(.vertical, 60)
                    .transition(.move(edge: .trailing))
            }
        }
        .sheet(isPresented: $showFrameExport) {
            if let item = viewerState.currentImage, let img = displayImage {
                FrameExportView(item: item, sourceImage: img)
                    .interactiveDismissDisabled()
            }
        }
        .toast(message: Binding(get: { appState.toastMessage }, set: { appState.toastMessage = $0 }))
        .focusable()
        .onKeyPress(phases: .down) { press in
            guard !showFrameExport else { return .ignored }
            switch press.key {
            case .rightArrow:
                viewerState.nextImage()
                return .handled
            case .leftArrow:
                viewerState.previousImage()
                return .handled
            case .escape:
                if showEXIF {
                    showEXIF = false
                } else {
                    dismiss()
                }
                return .handled
            default:
                return .ignored
            }
        }
        .onAppear {
            viewerState.openFile(url: initialURL)
        }
        .onChange(of: viewerState.currentIndex) {
            Task { await loadCurrentImage() }
        }
        .task {
            await loadCurrentImage()
        }
    }

    // MARK: - Subviews

    private var statusBar: some View {
        HStack {
            if let item = viewerState.currentImage {
                Text(item.filename)

                if item.isRAW {
                    Text("RAW")
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Spacer()

            Text(viewerState.statusMessage)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.black.opacity(0.6))
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if !isLoading, displayImage != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showEXIF.toggle()
                    }
                } label: {
                    Label("EXIF", systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showFrameExport = true
                } label: {
                    Label("边框水印", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if let item = viewerState.currentImage, item.isRAW, !isLoading {
                rawButton
            }
        }
    }

    private var exifPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXIF 信息")
                .font(.headline)

            Divider()

            exifRow("相机", exifData.displayModel)
            exifRow("镜头", exifData.lensModel)
            exifRow("焦距", exifData.focalLength)
            exifRow("光圈", exifData.aperture)
            exifRow("快门", exifData.shutterSpeed)
            exifRow("ISO", exifData.iso)
            exifRow("日期", exifData.dateTaken)
            exifRow("位置", exifData.location)
            exifRow("作者", exifData.author)
        }
        .padding(12)
        .frame(width: 220)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func exifRow(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
            }
        }
    }

    private var rawButton: some View {
        Group {
            if isDecodingRAW {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("解码中...")
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            } else if rawDecoded {
                Label("已解码", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
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
        .animation(.easeInOut(duration: 0.2), value: isDecodingRAW)
        .animation(.easeInOut(duration: 0.2), value: rawDecoded)
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

    // MARK: - Loading

    private func loadCurrentImage() async {
        guard let item = viewerState.currentImage else { return }
        isLoading = true
        errorMessage = nil
        displayImage = nil
        isDecodingRAW = false
        rawDecoded = false

        exifData = EXIFReader.read(from: item.url)

        do {
            let image = try await rawProcessor.loadImage(url: item.url)
            displayImage = image
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func decodeRAW() async {
        guard let item = viewerState.currentImage else { return }
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
