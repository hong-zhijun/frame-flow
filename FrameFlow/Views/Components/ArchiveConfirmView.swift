import SwiftUI

struct ArchiveConfirmView: View {
    @State var targetURL: URL
    let starFilter: Int
    let imageCount: Int
    let onConfirm: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("归档确认")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("将 \(imageCount) 张 \(starFilter)星图片移动到：")
                    .font(.callout)

                HStack {
                    Text(targetURL.path(percentEncoded: false))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("更改") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.canCreateDirectories = true
                        panel.prompt = "选择文件夹"
                        panel.directoryURL = targetURL.deletingLastPathComponent()
                        if panel.runModal() == .OK, let url = panel.url {
                            targetURL = url
                        }
                    }
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("确认归档") { onConfirm(targetURL) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
