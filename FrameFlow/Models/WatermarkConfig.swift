import AppKit
import Foundation

struct WatermarkConfig: Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case text, image, tiled
        var id: Self { self }
        var label: String {
            switch self {
            case .text:  "文字"
            case .image: "图片"
            case .tiled: "平铺"
            }
        }
    }

    enum Position: String, CaseIterable, Identifiable {
        case topLeft, topCenter, topRight
        case midLeft, midCenter, midRight
        case bottomLeft, bottomCenter, bottomRight
        var id: Self { self }

        /// SwiftUI 9 宫格里 (column, row) — column: 0=左,1=中,2=右；row: 0=上,1=中,2=下
        var gridIndex: (col: Int, row: Int) {
            switch self {
            case .topLeft:      (0, 0)
            case .topCenter:    (1, 0)
            case .topRight:     (2, 0)
            case .midLeft:      (0, 1)
            case .midCenter:    (1, 1)
            case .midRight:     (2, 1)
            case .bottomLeft:   (0, 2)
            case .bottomCenter: (1, 2)
            case .bottomRight:  (2, 2)
            }
        }
    }

    var kind: Kind = .text

    // Text watermark
    var text: String = "© FrameFlow"
    /// 占图像最长边的百分比（0.02 = 2%）
    var fontSize: CGFloat = 0.035
    var textColor: NSColor = .white

    // Image watermark
    var imageURL: URL?
    /// 占图像宽度的百分比
    var imageScale: CGFloat = 0.15

    // Position（非平铺时生效）
    var position: Position = .bottomRight
    /// 占图像最短边的百分比
    var margin: CGFloat = 0.03

    // Common
    var opacity: CGFloat = 0.85

    // Tiled
    /// 重复单元间距占图像最长边的百分比
    var tileSpacing: CGFloat = 0.15
    /// 平铺旋转角度（度，逆时针）
    var tileRotationDegrees: CGFloat = -30
}
