import SwiftUI
import AppKit

@MainActor
private final class ColorPanelCoordinator: NSObject {
    var onChange: ((NSColor) -> Void)?

    @objc func colorDidChange(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}

private struct CustomColorButton: View {
    @Binding var selection: Color
    let coordinator: ColorPanelCoordinator

    var body: some View {
        Button {
            let panel = NSColorPanel.shared
            panel.showsAlpha = false
            panel.color = NSColor(selection)
            coordinator.onChange = { color in
                selection = Color(nsColor: color)
            }
            panel.setTarget(coordinator)
            panel.setAction(#selector(ColorPanelCoordinator.colorDidChange(_:)))
            panel.makeKeyAndOrderFront(nil)
        } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(selection)
                .frame(width: 36, height: 20)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.gray.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct FrameExportView: View {
    let items: [ImageItem]
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var sourceImage: NSImage?
    @State private var exifData: EXIFData
    @State private var previewImage: NSImage?
    @State private var isExporting = false
    @State private var isInitialLoading = true
    @State private var previewTask: Task<Void, Never>?
    @State private var previewGeneration: Int = 0
    @State private var exportMessage = ""
    @State private var rightMainText = ""
    @State private var showBorder = false
    @State private var primaryColor: Color = .black
    @State private var secondaryColor: Color = .gray
    @State private var logoScale: Double = 1.0
    private let logoScaleOptions: [Double] = [0.5, 0.7, 0.8, 0.9, 1.0, 1.2, 1.5, 2.0]
    @State private var availableBrands: [String] = []
    @State private var selectedBrand: String = ""
    @State private var isCustomBrand = false
    @State private var colorCoordinator = ColorPanelCoordinator()
    @State private var editMode: EditMode = .frame
    @State private var watermark = WatermarkConfig()
    @State private var watermarkColor: Color = .white
    private let rawProcessor = RAWProcessor()

    enum EditMode: String, CaseIterable, Identifiable {
        case frame, watermark, both
        var id: Self { self }
        var label: String {
            switch self {
            case .frame: "边框"
            case .watermark: "水印"
            case .both: "边框 + 水印"
            }
        }
        var includeFrame: Bool { self != .watermark }
        var includeWatermark: Bool { self != .frame }
    }

    private var isBatch: Bool { items.count > 1 }
    private var firstItem: ImageItem { items[0] }

    init(item: ImageItem, sourceImage: NSImage) {
        self.items = [item]
        self._sourceImage = State(initialValue: sourceImage)
        self._exifData = State(initialValue: EXIFReader.read(from: item.url))
    }

    init(items: [ImageItem]) {
        precondition(!items.isEmpty, "FrameExportView 批量模式至少需要一张图片")
        self.items = items
        self._sourceImage = State(initialValue: nil)
        self._exifData = State(initialValue: EXIFReader.read(from: items[0].url))
    }

    var body: some View {
        HStack(spacing: 0) {
            previewPanel
                .frame(minWidth: 400, idealWidth: 500)

            Divider()

            editPanel
                .frame(width: 340)
        }
        .frame(minWidth: 900, minHeight: 640)
        .frame(maxHeight: 780)
        .onExitCommand {
            if !NSColorPanel.shared.isVisible {
                dismiss()
            }
        }
        .onAppear {
            availableBrands = Self.loadAvailableBrands()
            let matched = availableBrands.first { brand in
                let makeLower = exifData.cameraMake.lowercased()
                let brandLower = brand.lowercased()
                return makeLower == brandLower || makeLower.contains(brandLower)
            }
            if let matched {
                selectedBrand = matched
            } else {
                isCustomBrand = true
                selectedBrand = "自定义"
            }
            rightMainText = exifData.parameterLine
            Task {
                if sourceImage == nil {
                    sourceImage = try? await rawProcessor.loadImage(url: firstItem.url)
                }
                await updatePreview()
                isInitialLoading = false
            }
        }
        .onChange(of: exifData) { schedulePreviewUpdate() }
        .onChange(of: rightMainText) { schedulePreviewUpdate() }
        .onChange(of: showBorder) { schedulePreviewUpdate() }
        .onChange(of: selectedBrand) { schedulePreviewUpdate() }
        .onChange(of: logoScale) { schedulePreviewUpdate() }
        .onChange(of: primaryColor) { schedulePreviewUpdate() }
        .onChange(of: secondaryColor) { schedulePreviewUpdate() }
        .onChange(of: editMode) { schedulePreviewUpdate() }
        .onChange(of: watermark) { schedulePreviewUpdate() }
        .onChange(of: watermarkColor) { _, newValue in
            watermark.textColor = NSColor(newValue)
        }
        .onDisappear {
            previewTask?.cancel()
            colorCoordinator.onChange = nil
            let panel = NSColorPanel.shared
            panel.setTarget(nil)
            panel.setAction(nil)
        }
    }

    private var previewPanel: some View {
        ZStack {
            if let preview = previewImage {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
                    .transition(.opacity)
            }

            if isInitialLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在生成预览...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: previewGeneration)
        .background(Color.gray.opacity(0.1))
    }

    private var editPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isBatch ? "批量边框水印（\(items.count) 张）" : "边框水印")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Picker("", selection: $editMode) {
                ForEach(EditMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if editMode.includeFrame {
                        frameSettings
                    }
                    if editMode == .both {
                        Divider()
                        Text("水印")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    if editMode.includeWatermark {
                        watermarkSettings
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Divider()

            VStack(spacing: 8) {
                if !exportMessage.isEmpty, !isExporting {
                    Text(exportMessage)
                        .font(.callout)
                        .foregroundStyle(exportMessage.contains("失败") ? .red : .green)
                }

                HStack {
                    Button("取消") { dismiss() }
                        .disabled(isExporting)

                    Spacer()

                    if isExporting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(exportMessage.isEmpty ? "正在导出..." : exportMessage)
                                .font(.callout)
                        }
                    } else {
                        Button(isBatch ? "应用到 \(items.count) 张" : "导出") {
                            Task { await exportImage() }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(sourceImage == nil)
                    }
                }
            }
            .padding(16)
        }
    }

    private var frameSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            brandPicker
            fieldSection("相机型号", text: $exifData.cameraModel)
            fieldSection("镜头", text: $exifData.lensModel)

            Divider()

            fieldSection("右侧主文字", text: $rightMainText)

            Divider()

            fieldSection("拍摄日期", text: $exifData.dateTaken)
            fieldSection("位置", text: $exifData.location)
            fieldSection("作者", text: $exifData.author)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                colorRow(label: "主文字颜色", selection: $primaryColor)
                colorRow(label: "副文字颜色", selection: $secondaryColor)
            }

            Toggle("显示边框", isOn: $showBorder)
                .font(.callout)
        }
    }

    private var watermarkSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("类型", selection: $watermark.kind) {
                ForEach(WatermarkConfig.Kind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if watermark.kind == .text || watermark.kind == .tiled {
                fieldSection("水印文字", text: $watermark.text)
            }

            if watermark.kind == .image || watermark.kind == .tiled {
                imagePickerRow
            }

            if watermark.kind != .tiled {
                positionPicker
            }

            if watermark.kind == .text || watermark.kind == .tiled {
                sliderRow(label: "文字大小", value: $watermark.fontSize, range: 0.015...0.10, format: "%.0f%%", scale: 100)
            }

            if watermark.kind == .image || watermark.kind == .tiled {
                sliderRow(label: "图像尺寸", value: $watermark.imageScale, range: 0.05...0.50, format: "%.0f%%", scale: 100)
            }

            sliderRow(label: "不透明度", value: $watermark.opacity, range: 0.1...1.0, format: "%.0f%%", scale: 100)

            if watermark.kind != .tiled {
                sliderRow(label: "边距", value: $watermark.margin, range: 0.0...0.10, format: "%.0f%%", scale: 100)
            }

            if watermark.kind == .tiled {
                sliderRow(label: "平铺间距", value: $watermark.tileSpacing, range: 0.05...0.50, format: "%.0f%%", scale: 100)
                sliderRow(label: "旋转角度", value: $watermark.tileRotationDegrees, range: -90...90, format: "%.0f°", scale: 1)
            }

            if watermark.kind == .text || watermark.kind == .tiled {
                colorRow(label: "文字颜色", selection: $watermarkColor)
            }
        }
    }

    private var positionPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("位置")
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                ForEach(0..<3) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<3) { col in
                            let pos = position(forCol: col, row: row)
                            Button {
                                watermark.position = pos
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(watermark.position == pos ? Color.accentColor : Color.gray.opacity(0.18))
                                    .frame(width: 36, height: 24)
                                    .overlay(
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 6))
                                            .foregroundStyle(watermark.position == pos ? Color.white : Color.gray)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func position(forCol col: Int, row: Int) -> WatermarkConfig.Position {
        WatermarkConfig.Position.allCases.first { $0.gridIndex == (col, row) } ?? .bottomRight
    }

    private var imagePickerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("水印图片")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Text(watermark.imageURL?.lastPathComponent ?? "未选择")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("选择...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp]
                    panel.prompt = "选择"
                    if panel.runModal() == .OK, let url = panel.url {
                        watermark.imageURL = url
                    }
                }
                .controlSize(.small)
                if watermark.imageURL != nil {
                    Button("清除") { watermark.imageURL = nil }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func sliderRow(label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, format: String, scale: CGFloat) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue * scale))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
                .monospacedDigit()
        }
    }

    private var brandPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("相机 Logo")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Picker("", selection: $selectedBrand) {
                    ForEach(availableBrands, id: \.self) { brand in
                        Text(brand).tag(brand)
                    }
                    Divider()
                    Text("自定义").tag("自定义")
                }
                .labelsHidden()
                .onChange(of: selectedBrand) { _, newValue in
                    if newValue == "自定义" {
                        isCustomBrand = true
                    } else {
                        isCustomBrand = false
                        exifData.cameraMake = newValue
                    }
                }

                Picker("", selection: $logoScale) {
                    ForEach(logoScaleOptions, id: \.self) { scale in
                        Text(String(format: "%.1fx", scale)).tag(scale)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
            }

            if isCustomBrand {
                TextField("输入品牌名", text: $exifData.cameraMake)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
            }
        }
    }

    private static func loadAvailableBrands() -> [String] {
        guard let logosURL = Bundle.main.url(forResource: "Logos", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: logosURL, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension.lowercased() == "png" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    private func colorRow(label: String, selection: Binding<Color>) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            CustomColorButton(selection: selection, coordinator: colorCoordinator)
        }
    }

    private func fieldSection(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
        }
    }

    private func schedulePreviewUpdate() {
        previewTask?.cancel()
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            await updatePreview()
        }
    }

    private func updatePreview() async {
        guard let img = sourceImage else { return }
        let style = currentStyle()
        let logo = loadLogo(for: exifData.cameraMake)
        let exif = exifData
        let text = rightMainText
        let mode = editMode
        let watermarkCfg = watermark
        let result = await Task.detached {
            Self.runPipeline(
                image: img, exif: exif, style: style, logo: logo,
                rightMainText: text, mode: mode, watermark: watermarkCfg
            )
        }.value
        guard !Task.isCancelled else { return }
        previewImage = result
        previewGeneration += 1
    }

    /// 按当前编辑模式跑渲染管线：source → (watermark?) → (frame?) → output
    nonisolated private static func runPipeline(
        image: NSImage,
        exif: EXIFData,
        style: FrameStyle,
        logo: NSImage?,
        rightMainText: String,
        mode: EditMode,
        watermark: WatermarkConfig
    ) -> NSImage? {
        var current = image
        if mode.includeWatermark {
            if let withMark = WatermarkRenderer.apply(image: current, config: watermark) {
                current = withMark
            }
        }
        if mode.includeFrame {
            if let withFrame = FrameRenderer.render(image: current, exif: exif, style: style, logoImage: logo, rightMainText: rightMainText) {
                current = withFrame
            }
        }
        return current
    }

    private func exportImage() async {
        if isBatch {
            await batchExport()
        } else {
            await singleExport()
        }
    }

    private func singleExport() async {
        guard let img = sourceImage else { return }
        isExporting = true
        exportMessage = ""

        let style = currentStyle()
        let logo = loadLogo(for: exifData.cameraMake)
        let exif = exifData
        let itemURL = firstItem.url
        let text = rightMainText
        let mode = editMode
        let watermarkCfg = watermark

        let result = await Task.detached {
            guard let rendered = Self.runPipeline(
                image: img, exif: exif, style: style, logo: logo,
                rightMainText: text, mode: mode, watermark: watermarkCfg
            ) else {
                return (false, "渲染失败")
            }

            let folderURL = itemURL.deletingLastPathComponent()
            let exportDir = folderURL.appendingPathComponent("图片边框", isDirectory: true)
            try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

            let baseName = itemURL.deletingPathExtension().lastPathComponent
            var exportURL = exportDir.appendingPathComponent("\(baseName)_framed.jpg")

            var counter = 1
            while FileManager.default.fileExists(atPath: exportURL.path(percentEncoded: false)) {
                exportURL = exportDir.appendingPathComponent("\(baseName)_framed_\(counter).jpg")
                counter += 1
            }

            let success = FrameRenderer.exportAsJPEG(rendered, to: exportURL)
            return (success, success ? "" : "导出失败")
        }.value

        if result.0 {
            appState.toastMessage = "导出成功，请到「图片边框」文件夹查看"
            dismiss()
        } else {
            exportMessage = result.1
            isExporting = false
        }
    }

    private func batchExport() async {
        isExporting = true
        exportMessage = ""

        let style = currentStyle()
        let logo = loadLogo(for: exifData.cameraMake)
        let exif = exifData
        let text = rightMainText
        let mode = editMode
        let watermarkCfg = watermark
        let total = items.count

        var successCount = 0
        for (idx, item) in items.enumerated() {
            exportMessage = "正在处理 \(idx + 1) / \(total)"
            let itemURL = item.url
            let img: NSImage?
            do {
                img = try await rawProcessor.loadImage(url: itemURL)
            } catch {
                continue
            }
            guard let img else { continue }

            let ok = await Task.detached {
                guard let rendered = Self.runPipeline(
                    image: img, exif: exif, style: style, logo: logo,
                    rightMainText: text, mode: mode, watermark: watermarkCfg
                ) else {
                    return false
                }

                let folderURL = itemURL.deletingLastPathComponent()
                let exportDir = folderURL.appendingPathComponent("图片边框", isDirectory: true)
                try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

                let baseName = itemURL.deletingPathExtension().lastPathComponent
                var exportURL = exportDir.appendingPathComponent("\(baseName)_framed.jpg")
                var counter = 1
                while FileManager.default.fileExists(atPath: exportURL.path(percentEncoded: false)) {
                    exportURL = exportDir.appendingPathComponent("\(baseName)_framed_\(counter).jpg")
                    counter += 1
                }
                return FrameRenderer.exportAsJPEG(rendered, to: exportURL)
            }.value

            if ok { successCount += 1 }
        }

        appState.toastMessage = "已套壳 \(successCount) / \(total) 张"
        appState.clearSelection()
        isExporting = false
        dismiss()
    }

    private func currentStyle() -> FrameStyle {
        var style = FrameStyle()
        style.borderEnabled = showBorder
        style.logoScale = logoScale
        style.textColor = NSColor(primaryColor)
        style.secondaryTextColor = NSColor(secondaryColor)
        return style
    }

    private func loadLogo(for make: String) -> NSImage? {
        let normalized = make.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        guard let logosURL = Bundle.main.url(forResource: "Logos", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: logosURL, includingPropertiesForKeys: nil) else {
            return nil
        }

        let makeLower = normalized.lowercased()
        let firstWord = makeLower.split(separator: " ").first.map(String.init) ?? makeLower

        for file in files where file.pathExtension.lowercased() == "png" {
            let logoName = file.deletingPathExtension().lastPathComponent.lowercased()
            if makeLower == logoName || firstWord == logoName || makeLower.contains(logoName) {
                return NSImage(contentsOf: file)
            }
        }
        return nil
    }
}
