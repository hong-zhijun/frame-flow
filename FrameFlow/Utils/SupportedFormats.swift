import UniformTypeIdentifiers

enum SupportedFormats {
    static let standardExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif",
        "tiff", "tif", "bmp", "gif", "webp"
    ]

    static let rawExtensions: Set<String> = [
        "cr2", "cr3", "nef", "arw", "dng",
        "raf", "orf", "rw2", "pef", "srw", "3fr"
    ]

    static let allExtensions: Set<String> = standardExtensions.union(rawExtensions)

    static func isSupported(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if allExtensions.contains(ext) { return true }

        if let utType = UTType(filenameExtension: ext) {
            return utType.conforms(to: .image)
        }
        return false
    }

    static func isRAW(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if rawExtensions.contains(ext) { return true }

        if let utType = UTType(filenameExtension: ext) {
            return utType.conforms(to: .rawImage)
        }
        return false
    }
}
