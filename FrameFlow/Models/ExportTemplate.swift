import AppKit
import Foundation

struct ExportTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    var createdAt: Date

    var editMode: String
    var showBorder: Bool
    var primaryColorHex: String
    var secondaryColorHex: String
    var logoScale: Double
    var brandName: String

    var watermarkKind: String
    var watermarkText: String
    var watermarkFontSize: CGFloat
    var watermarkTextColorHex: String
    var watermarkImagePath: String?
    var watermarkImageScale: CGFloat
    var watermarkPosition: String
    var watermarkMargin: CGFloat
    var watermarkOpacity: CGFloat
    var watermarkTileSpacing: CGFloat
    var watermarkTileRotationDegrees: CGFloat
}

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    convenience init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
