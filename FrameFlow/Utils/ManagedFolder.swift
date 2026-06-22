import Foundation

/// 标记一个目录为「App 自动生成」（如归档、套壳输出）。
/// FolderScanner 扫描时会跳过含有此标记的目录，避免把 App 自己的产物再回扫到网格里。
enum ManagedFolder {
    static let markerFilename = ".frameflow-managed"

    static func markerURL(in directory: URL) -> URL {
        directory.appendingPathComponent(markerFilename)
    }

    /// 在目录下写入隐藏标记文件。失败静默——下一次扫描就会把它当成普通文件夹，仅是回退到旧行为。
    static func mark(_ directory: URL) {
        let url = markerURL(in: directory)
        try? Data().write(to: url, options: .atomic)
    }

    static func isManaged(_ directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: markerURL(in: directory).path(percentEncoded: false))
    }
}
