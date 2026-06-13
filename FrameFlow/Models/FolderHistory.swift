import Foundation

struct RecentFolder: Codable, Identifiable, Hashable {
    var id: String { path }
    let path: String
    let name: String
    var lastOpened: Date

    var url: URL { URL(fileURLWithPath: path) }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
}

@Observable
final class FolderHistory {
    private static let storageKey = "recentFolders"
    private static let maxEntries = 20

    var folders: [RecentFolder] = []

    init() {
        load()
    }

    func add(_ url: URL) {
        let path = url.path(percentEncoded: false)
        if let index = folders.firstIndex(where: { $0.path == path }) {
            folders[index].lastOpened = Date()
        } else {
            let entry = RecentFolder(
                path: path,
                name: url.lastPathComponent,
                lastOpened: Date()
            )
            folders.insert(entry, at: 0)
        }

        folders.sort { $0.lastOpened > $1.lastOpened }
        if folders.count > Self.maxEntries {
            folders = Array(folders.prefix(Self.maxEntries))
        }
        save()
    }

    func remove(_ folder: RecentFolder) {
        folders.removeAll { $0.id == folder.id }
        save()
    }

    func clearAll() {
        folders.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([RecentFolder].self, from: data) else {
            return
        }
        folders = decoded
    }
}
