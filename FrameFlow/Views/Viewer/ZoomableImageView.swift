import SwiftUI
import AppKit

struct ZoomableImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> ZoomableScrollContainer {
        ZoomableScrollContainer()
    }

    func updateNSView(_ nsView: ZoomableScrollContainer, context: Context) {
        nsView.setImage(image)
    }
}

final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let docView = documentView else { return rect }

        let docFrame = docView.frame
        if docFrame.width < rect.width {
            rect.origin.x = (docFrame.width - rect.width) / 2
        }
        if docFrame.height < rect.height {
            rect.origin.y = (docFrame.height - rect.height) / 2
        }
        return rect
    }
}

final class ZoomScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command) {
            super.scrollWheel(with: event)
            return
        }

        let delta = event.scrollingDeltaY
        guard abs(delta) > 0.01 else { return }

        let zoomFactor: CGFloat = 1.0 + (delta * 0.02)
        let newMag = min(max(magnification * zoomFactor, minMagnification), maxMagnification)

        let locationInClip = contentView.convert(event.locationInWindow, from: nil)
        setMagnification(newMag, centeredAt: locationInClip)
    }
}

final class ZoomableScrollContainer: NSView {
    private let scrollView = ZoomScrollView()
    private let clipView = CenteringClipView()
    private let imageView = NSImageView()
    private var currentImage: NSImage?
    private var imagePixelSize: NSSize = .zero
    private var isDragging = false
    private var lastDragPoint: NSPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        clipView.drawsBackground = true
        clipView.backgroundColor = .black
        scrollView.contentView = clipView

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.backgroundColor = .black
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.scrollerStyle = .overlay
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 50.0
        scrollView.usesPredominantAxisScrolling = false

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true

        scrollView.documentView = imageView
        addSubview(scrollView)
    }

    func setImage(_ image: NSImage) {
        guard image !== currentImage else { return }
        currentImage = image
        imagePixelSize = image.effectivePixelSize
        imageView.image = image

        scrollView.magnification = 1.0
        fitImageViewToWindow()
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds

        if currentImage != nil, scrollView.magnification == 1.0 {
            fitImageViewToWindow()
        }
    }

    private func fitImageViewToWindow() {
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else { return }

        let viewSize = scrollView.contentSize
        guard viewSize.width > 0, viewSize.height > 0 else { return }

        let scaleX = viewSize.width / imagePixelSize.width
        let scaleY = viewSize.height / imagePixelSize.height
        let fitScale = min(scaleX, scaleY)

        let fittedW = imagePixelSize.width * fitScale
        let fittedH = imagePixelSize.height * fitScale

        imageView.frame = NSRect(origin: .zero, size: NSSize(width: fittedW, height: fittedH))
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                scrollView.animator().magnification = 1.0
            }
            fitImageViewToWindow()
            return
        }
        isDragging = true
        lastDragPoint = convert(event.locationInWindow, from: nil)
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - lastDragPoint.x
        let dy = point.y - lastDragPoint.y
        lastDragPoint = point

        var origin = clipView.bounds.origin
        origin.x -= dx
        origin.y -= dy
        clipView.setBoundsOrigin(origin)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            NSCursor.pop()
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

extension NSImage {
    var effectivePixelSize: NSSize {
        guard let rep = representations.first else { return size }
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        if w > 0, h > 0 {
            return NSSize(width: w, height: h)
        }
        return size
    }
}
