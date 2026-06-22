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
    let item: ImageItem
    let sourceImage: NSImage
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var exifData: EXIFData
    @State private var previewImage: NSImage?
    @State private var isExporting = false
    @State private var isGeneratingPreview = true
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

    init(item: ImageItem, sourceImage: NSImage) {
        self.item = item
        self.sourceImage = sourceImage
        self._exifData = State(initialValue: EXIFReader.read(from: item.url))
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
            Task { await updatePreview() }
        }
        .onChange(of: exifData.cameraMake) { Task { await updatePreview() } }
        .onChange(of: exifData.cameraModel) { Task { await updatePreview() } }
        .onChange(of: exifData.lensModel) { Task { await updatePreview() } }
        .onChange(of: rightMainText) { Task { await updatePreview() } }
        .onChange(of: exifData.dateTaken) { Task { await updatePreview() } }
        .onChange(of: exifData.location) { Task { await updatePreview() } }
        .onChange(of: exifData.author) { Task { await updatePreview() } }
        .onChange(of: showBorder) { Task { await updatePreview() } }
        .onChange(of: selectedBrand) { Task { await updatePreview() } }
        .onChange(of: logoScale) { Task { await updatePreview() } }
        .onChange(of: primaryColor) { Task { await updatePreview() } }
        .onChange(of: secondaryColor) { Task { await updatePreview() } }
        .onDisappear {
            // sheet 关闭后，断开与全局 NSColorPanel 的回调，避免 coordinator 释放后回调悬空
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
            }

            if isGeneratingPreview {
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
        .background(Color.gray.opacity(0.1))
    }

    private var editPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("图片边框")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ScrollView {
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Divider()

            VStack(spacing: 8) {
                if !exportMessage.isEmpty {
                    Text(exportMessage)
                        .font(.callout)
                        .foregroundStyle(exportMessage.contains("成功") ? .green : .red)
                }

                HStack {
                    Button("取消") { dismiss() }
                        .disabled(isExporting)

                    Spacer()

                    if isExporting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在导出...")
                                .font(.callout)
                        }
                    } else {
                        Button("导出") { Task { await exportImage() } }
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(16)
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

    private func updatePreview() async {
        isGeneratingPreview = true
        let style = currentStyle()
        let logo = loadLogo(for: exifData.cameraMake)
        let img = sourceImage
        let exif = exifData
        let text = rightMainText
        let result = await Task.detached {
            FrameRenderer.render(image: img, exif: exif, style: style, logoImage: logo, rightMainText: text)
        }.value
        previewImage = result
        isGeneratingPreview = false
    }

    private func exportImage() async {
        isExporting = true
        exportMessage = ""

        let style = currentStyle()
        let logo = loadLogo(for: exifData.cameraMake)
        let img = sourceImage
        let exif = exifData
        let itemURL = item.url

        let text = rightMainText
        let result = await Task.detached {
            guard let rendered = FrameRenderer.render(image: img, exif: exif, style: style, logoImage: logo, rightMainText: text) else {
                return (false, "", "渲染失败")
            }

            let folderURL = itemURL.deletingLastPathComponent()
            let exportDir = folderURL.appendingPathComponent("图片边框", isDirectory: true)
            try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            ManagedFolder.mark(exportDir)

            let baseName = itemURL.deletingPathExtension().lastPathComponent
            var exportURL = exportDir.appendingPathComponent("\(baseName)_framed.jpg")

            var counter = 1
            while FileManager.default.fileExists(atPath: exportURL.path(percentEncoded: false)) {
                exportURL = exportDir.appendingPathComponent("\(baseName)_framed_\(counter).jpg")
                counter += 1
            }

            let success = FrameRenderer.exportAsJPEG(rendered, to: exportURL)
            return (success, exportURL.lastPathComponent, success ? "" : "导出失败")
        }.value

        if result.0 {
            appState.toastMessage = "导出成功，请到「图片边框」文件夹查看"
            dismiss()
        } else {
            exportMessage = result.2
            isExporting = false
        }
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
