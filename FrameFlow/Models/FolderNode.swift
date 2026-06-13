import Foundation

struct FolderNode: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    var children: [FolderNode]
    var images: [ImageItem]

    var imageCount: Int {
        images.count + children.reduce(0) { $0 + $1.imageCount }
    }

    static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
