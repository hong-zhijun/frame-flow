import SwiftUI

struct HistoryListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.folderHistory.folders.isEmpty {
            Text("暂无历史记录")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            ForEach(appState.folderHistory.folders) { folder in
                historyRow(folder)
            }
        }
    }

    private func historyRow(_ folder: RecentFolder) -> some View {
        HStack {
            Image(systemName: "clock")
                .font(.body)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.body)
                    .lineLimit(1)
                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets(top: -4, leading: 0, bottom: -4, trailing: 0))
        .onTapGesture {
            guard folder.exists else {
                appState.statusMessage = "文件夹不存在: \(folder.name)"
                return
            }
            Task { @MainActor in
                await appState.openFolder(folder.url, includeSubfolders: true)
            }
        }
        .contextMenu {
            Button("移除") {
                appState.folderHistory.remove(folder)
            }
        }
    }
}
