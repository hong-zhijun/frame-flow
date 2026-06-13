import SwiftUI

struct FolderTreeView: View {
    let node: FolderNode
    @Environment(AppState.self) private var appState

    private var isSelected: Bool {
        appState.selectedFolderURL == node.url
    }

    var body: some View {
        if node.children.isEmpty {
            folderLabel
                .onTapGesture { selectFolder(node) }
        } else {
            DisclosureGroup {
                ForEach(node.children) { child in
                    FolderTreeView(node: child)
                }
            } label: {
                folderLabel
                    .onTapGesture { selectFolder(node) }
            }
        }
    }

    private var folderLabel: some View {
        HStack {
            Image(systemName: "folder.fill")
                .font(.body)
                .foregroundStyle(isSelected ? .white : .blue)
            Text(node.name)
                .font(.body)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .white : .primary)
            Spacer()
            Text("\(node.images.count)")
                .font(.callout)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets(top: -4, leading: 0, bottom: -4, trailing: 0))
    }

    private func selectFolder(_ node: FolderNode) {
        Task { await appState.refreshFolder(node) }
    }
}
