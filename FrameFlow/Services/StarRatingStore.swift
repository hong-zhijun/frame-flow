import Foundation

@MainActor @Observable
final class StarRatingStore {
    private var ratings: [String: Int] = [:]
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("FrameFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("star-ratings.json")
        load()
    }

    func rating(for url: URL) -> Int {
        ratings[url.path(percentEncoded: false)] ?? 0
    }

    func setRating(_ rating: Int, for url: URL) {
        let path = url.path(percentEncoded: false)
        if rating == 0 {
            ratings.removeValue(forKey: path)
        } else {
            ratings[path] = max(1, min(5, rating))
        }
        save()
    }

    func cleanupStaleEntries(in folderURL: URL) {
        let fm = FileManager.default
        var folderPath = folderURL.path(percentEncoded: false)
        if !folderPath.hasSuffix("/") { folderPath += "/" }
        var changed = false
        for key in ratings.keys {
            if key.hasPrefix(folderPath) && !fm.fileExists(atPath: key) {
                ratings.removeValue(forKey: key)
                changed = true
            }
        }
        if changed { save() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
        ratings = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(ratings) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
