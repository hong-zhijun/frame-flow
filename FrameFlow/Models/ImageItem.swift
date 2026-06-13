import AppKit
import UniformTypeIdentifiers

struct ImageItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let filename: String
    let fileExtension: String
    let isRAW: Bool
    let formatLabel: String

    init(url: URL) {
        self.url = url
        self.filename = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.isRAW = SupportedFormats.rawExtensions.contains(self.fileExtension)
        self.formatLabel = Self.label(for: self.fileExtension)
    }

    enum FormatCategory: CaseIterable {
        case raw, jpeg, png, heic, gif, tiff, other

        var label: String {
            switch self {
            case .raw: "RAW"
            case .jpeg: "JPG"
            case .png: "PNG"
            case .heic: "HEIC"
            case .gif: "GIF"
            case .tiff: "TIFF"
            case .other: "其他"
            }
        }
    }

    var formatCategory: FormatCategory {
        switch fileExtension {
        case "cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "pef", "srw", "3fr": .raw
        case "jpg", "jpeg": .jpeg
        case "png": .png
        case "heic", "heif": .heic
        case "gif": .gif
        case "tiff", "tif": .tiff
        default: .other
        }
    }

    private static func label(for ext: String) -> String {
        switch ext {
        case "jpg", "jpeg": "JPG"
        case "png": "PNG"
        case "heic", "heif": "HEIC"
        case "tiff", "tif": "TIFF"
        case "bmp": "BMP"
        case "gif": "GIF"
        case "webp": "WEBP"
        case "svg": "SVG"
        case "ico": "ICO"
        case "avif": "AVIF"
        case "cr2": "CR2"
        case "cr3": "CR3"
        case "nef": "NEF"
        case "arw": "ARW"
        case "dng": "DNG"
        case "raf": "RAF"
        case "orf": "ORF"
        case "rw2": "RW2"
        case "pef": "PEF"
        case "srw": "SRW"
        case "3fr": "3FR"
        default: ext.uppercased()
        }
    }

    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
