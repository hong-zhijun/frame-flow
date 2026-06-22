import Foundation
import ImageIO
import CoreLocation

struct EXIFData {
    var cameraMake: String
    var cameraModel: String
    var lensModel: String
    var focalLength: String
    var aperture: String
    var shutterSpeed: String
    var iso: String
    var dateTaken: String
    var location: String
    var author: String

    var parameterLine: String {
        [focalLength, aperture, shutterSpeed, iso]
            .filter { !$0.isEmpty }
            .joined(separator: "  ")
    }

    var displayModel: String {
        if cameraModel.lowercased().contains(cameraMake.lowercased()) {
            return cameraModel
        }
        return [cameraMake, cameraModel].filter { !$0.isEmpty }.joined(separator: " ")
    }

    static let empty = EXIFData(
        cameraMake: "", cameraModel: "", lensModel: "",
        focalLength: "", aperture: "", shutterSpeed: "",
        iso: "", dateTaken: "", location: "", author: ""
    )
}

enum EXIFReader {
    static func read(from url: URL) -> EXIFData {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return .empty
        }

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]

        let make = tiff[kCGImagePropertyTIFFMake] as? String ?? ""
        let model = tiff[kCGImagePropertyTIFFModel] as? String ?? ""
        let lens = exif[kCGImagePropertyExifLensModel] as? String ?? ""

        var focalLength = ""
        if let fl = exif[kCGImagePropertyExifFocalLength] as? Double {
            focalLength = "\(Int(fl))mm"
        }

        var aperture = ""
        if let ap = exif[kCGImagePropertyExifFNumber] as? Double {
            aperture = String(format: "f/%.1f", ap)
        }

        var shutterSpeed = ""
        if let et = exif[kCGImagePropertyExifExposureTime] as? Double {
            if et >= 1 {
                shutterSpeed = String(format: "%.1fs", et)
            } else {
                shutterSpeed = "1/\(Int(round(1.0 / et)))s"
            }
        }

        var iso = ""
        if let isoValues = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let first = isoValues.first {
            iso = "ISO \(first)"
        }

        var dateTaken = ""
        if let dateStr = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            dateTaken = formatDate(dateStr)
        }

        let location = parseGPS(gps)

        let author = tiff[kCGImagePropertyTIFFArtist] as? String ?? ""

        return EXIFData(
            cameraMake: cleanString(make),
            cameraModel: cleanString(model),
            lensModel: cleanString(lens),
            focalLength: focalLength,
            aperture: aperture,
            shutterSpeed: shutterSpeed,
            iso: iso,
            dateTaken: dateTaken,
            location: location,
            author: author
        )
    }

    private static func cleanString(_ str: String) -> String {
        str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: " ")
        guard let datePart = parts.first else { return dateStr }
        return datePart.replacingOccurrences(of: ":", with: "-")
    }

    private static func parseGPS(_ gps: [CFString: Any]) -> String {
        guard let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
              let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
              let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String else {
            return ""
        }

        let latitude = latRef == "S" ? -lat : lat
        let longitude = lonRef == "W" ? -lon : lon

        return String(format: "%.4f, %.4f", latitude, longitude)
    }
}
