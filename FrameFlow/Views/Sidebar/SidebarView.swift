import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            if let folder = appState.currentFolder {
                Section {
                    FolderTreeView(node: folder)
                } header: {
                    Text("当前文件夹")
                        .font(.body)
                        .fontWeight(.semibold)
                        .textCase(nil)
                }
            }

            Section {
                HistoryListView()
            } header: {
                HStack {
                    Text("最近打开")
                        .font(.body)
                        .fontWeight(.semibold)
                        .textCase(nil)
                    Spacer()
                    if !appState.folderHistory.folders.isEmpty {
                        Menu {
                            Button("清除全部历史", role: .destructive) {
                                appState.folderHistory.clearAll()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 20, height: 20)
                        .padding(.trailing, 4)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("FrameFlow")
    }
}
