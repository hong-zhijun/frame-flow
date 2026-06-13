# FrameFlow V1 — Development Guide

## 1. Project Overview

FrameFlow is a native macOS image viewer built with Swift + SwiftUI, designed for photographers who need fast folder-based browsing, RAW format support, and smooth zoom/navigation.

- **Platform**: macOS 27+ (Tahoe)
- **Language**: Swift 6.4 (Xcode 27)
- **UI Framework**: SwiftUI
- **UI Language**: Chinese (all buttons, labels, tooltips, and prompts must be in Chinese)
- **Image Decoding**: ImageIO / Core Image (native RAW 9 support)
- **Data Persistence**: UserDefaults (folder history)

---

## 2. Swift 6.4 & SwiftUI (WWDC 2026) — Key Syntax & APIs

This project targets macOS 27 and should use the latest Swift 6.4 / SwiftUI APIs introduced at WWDC 2026.

### 2.1 Swift 6.4 Language Features

**`anyAppleOS` Availability**
Use the new shorthand instead of listing each platform:

```swift
@available(anyAppleOS 27, *)
func loadRAWImage(from url: URL) async throws -> NSImage { ... }
```

**Accessible Memberwise Initializers**
Swift now auto-generates memberwise initializers at different access levels based on property visibility. No need for manual boilerplate:

```swift
public struct ImageItem {
    public var url: URL
    public var filename: String
    var thumbnail: NSImage?  // internal
}
// Swift auto-generates both public and internal memberwise inits
```

**`@specialized` Attribute**
Emit dedicated optimized versions for specific types:

```swift
@specialized(where T == ImageItem)
func sortItems<T: Comparable>(_ items: [T]) -> [T] { ... }
```

**Module Selectors (`::`)**
Disambiguate name conflicts between imported modules:

```swift
let filter = CoreImage::CIFilter(name: "CIGaussianBlur")
```

**`borrow` / `mutate` Accessors**
Zero-copy read access for performance-critical image data:

```swift
struct ImageBuffer {
    var pixels: [UInt8]

    var count: Int {
        borrow { pixels.count }
    }
}
```

### 2.2 SwiftUI New APIs (WWDC 2026)

**NavigationSplitView (Sidebar Layout)**
Use for the folder tree + main content layout:

```swift
NavigationSplitView {
    SidebarView()
} detail: {
    ContentView()
}
```

**Swipe Actions on Any Container**
Now works beyond `List` — use in `ScrollView` + `LazyVStack`:

```swift
ScrollView {
    LazyVStack {
        ForEach(images) { image in
            ThumbnailView(image: image)
                .swipeActions(edge: .trailing) {
                    Button("删除", role: .destructive) { delete(image) }
                }
        }
    }
}
.swipeActionsContainer()
```

**Toolbar Minimization on Scroll**
Auto-hide the toolbar when scrolling through images:

```swift
.toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
```

**Navigation Transitions**
Smooth transitions between grid and viewer:

```swift
.navigationTransition(.crossFade)
```

**AsyncImage with Built-in Caching**
For URL-based image loading with automatic cache:

```swift
AsyncImage(request: URLRequest(url: imageURL))
    .asyncImageURLSession(ImageStore.imageSession)
```

**Window Active State Detection**
Respond to window focus for visual feedback:

```swift
@Environment(\.appearsActive) var isActive
```

**Keyboard Shortcuts**
Define keyboard shortcuts for navigation:

```swift
Button("下一张") { nextImage() }
    .keyboardShortcut(.space, modifiers: [])

Button("上一张") { previousImage() }
    .keyboardShortcut(.space, modifiers: .shift)

Button("下一张") { nextImage() }
    .keyboardShortcut(.rightArrow, modifiers: [])

Button("上一张") { previousImage() }
    .keyboardShortcut(.leftArrow, modifiers: [])
```

---

## 3. Core Image RAW 9 — API Reference

macOS 27 introduces **Core Image RAW 9**, the biggest RAW processing update since 2017. It uses a tiled CoreML model that combines demosaicing + denoising in a single pass, running on Apple Neural Engine cores.

### 3.1 Enabling RAW 9 Decoder

```swift
import CoreImage

let rawFilter = CIRAWFilter(imageURL: rawFileURL)!

// Check if RAW 9 is supported for this camera model
if rawFilter.supportedDecoderVersions.contains(.version9) {
    rawFilter.decoderVersion = .version9
}

// Get the processed CIImage
let outputImage = rawFilter.outputImage
```

### 3.2 Querying Supported Camera Models

```swift
// Get all camera models supported by RAW 9
let models = CIRAWFilter.supportedCameraModels(decoderVersion: .version9)
// Returns: ["Canon EOS R5", "Nikon Z9", "Sony A7R V", "Fujifilm X-T5", ...]
// 784+ camera models supported, including X-Trans sensors
```

### 3.3 Editing Properties

```swift
// Core editing controls (supported in RAW 9)
rawFilter.exposure = 0.5                        // Brighten/darken
rawFilter.luminanceNoiseReductionAmount = 0.7    // Luma grain
rawFilter.sharpnessAmount = 0.5                  // Edge sharpening
rawFilter.contrastAmount = 0.3                   // Local contrast

// Check if a property is supported for this file
if rawFilter.isSupported(property: .luminanceNoiseReductionAmount) {
    rawFilter.luminanceNoiseReductionAmount = 0.8
}

// NOTE: These properties are auto-handled by RAW 9's ML model,
// no longer needed to set manually:
// - colorNoiseReductionAmount (automatic)
// - detailAmount (deprecated)
// - moireReductionAmount (deprecated)
```

### 3.4 Performance Optimization for Interactive Viewing

```swift
// Use scaleFactor for responsive preview (not full resolution)
rawFilter.scaleFactor = 0.5

// Create CIContext with caching for interactive editing
let context = CIContext(options: [
    .cacheIntermediates: true
])

// Render to Metal-backed view for GPU acceleration
// Use MTKView for best performance
```

### 3.5 Export / Batch Processing

```swift
// Export context (no caching, memory-limited)
let exportContext = CIContext(options: [
    .cacheIntermediates: false,
    .memoryLimit: 512  // MB
])

// Export as HEIF or JPEG
let heifData = exportContext.heifRepresentation(of: outputImage)
let jpegData = exportContext.jpegRepresentation(of: outputImage)
```

### 3.6 Entitlements

Add to the app entitlements file for large RAW files:

```xml
<key>com.apple.developer.kernel.extended-virtual-addressing</key>
<true/>
```

---

## 4. Project Structure

```
FrameFlow/
├── FrameFlowApp.swift              # App entry point
├── Models/
│   ├── ImageItem.swift             # Image data model (url, filename, metadata)
│   ├── FolderNode.swift            # Folder tree node model
│   └── FolderHistory.swift         # Recent folders persistence
├── Views/
│   ├── MainWindow.swift            # NavigationSplitView root layout
│   ├── Sidebar/
│   │   ├── SidebarView.swift       # Folder tree + history
│   │   ├── FolderTreeView.swift    # Recursive folder tree
│   │   └── HistoryListView.swift   # Recent folders list
│   ├── Grid/
│   │   ├── ThumbnailGridView.swift # Photo grid layout
│   │   └── ThumbnailCell.swift     # Single thumbnail cell
│   └── Viewer/
│       ├── ImageViewerView.swift   # Full-size image viewer
│       └── ZoomableImageView.swift # Scroll-to-zoom + drag-to-pan
├── Services/
│   ├── FolderScanner.swift         # Async folder scanning + image filtering
│   ├── ImageLoader.swift           # Thumbnail + full-size async loading
│   └── RAWProcessor.swift          # CIRAWFilter wrapper (RAW 9)
└── Utils/
    └── SupportedFormats.swift      # Image format constants & detection
```

---

## 5. Feature Specifications

### 5.1 Folder Import & Browsing

**Entry Point**: Toolbar button "导入文件夹" opens `NSOpenPanel`:

```swift
let panel = NSOpenPanel()
panel.canChooseDirectories = true
panel.canChooseFiles = false
panel.allowsMultipleSelection = false
panel.message = "选择要导入的图片文件夹"
panel.prompt = "导入"
```

**Folder Scanning**:
- Run on background thread using `Task.detached`
- Recursively scan subfolders
- Filter supported formats: `jpg`, `jpeg`, `png`, `heic`, `heif`, `tiff`, `bmp`, `gif`, `webp`, `cr2`, `nef`, `arw`, `dng`, `raf`, `orf`, `rw2`
- Use `UTType` for reliable format detection, not just file extensions
- Build a `FolderNode` tree structure for sidebar display

**UI Layout**:
- Left sidebar: folder tree (expandable/collapsible)
- Right main area: thumbnail grid
- Click thumbnail → enter full-size viewer

### 5.2 Folder History

**Storage**: `UserDefaults` with key `recentFolders`

```swift
// Data model
struct RecentFolder: Codable {
    let path: String
    let name: String
    let lastOpened: Date
}
```

**Behavior**:
- Max 20 entries, sorted by `lastOpened` descending
- Show in sidebar under "最近打开" section with clock icon
- Click to re-open folder
- Right-click context menu: "移除" (remove single) / "清除全部历史" (clear all)
- On import, add/update entry automatically

### 5.3 Scroll-to-Zoom (Cursor-Anchored)

**Implementation**: Custom `NSView` wrapper or SwiftUI `MagnifyGesture` + `ScrollView`:

- Listen to `scrollWheel` events
- Calculate zoom anchor point at cursor position
- Zoom range: 10% – 1000%
- Smooth zoom animation
- Drag to pan (when zoomed in)
- Double-click to fit-to-window / toggle 100%
- Display current zoom percentage in status bar (e.g. "150%")

**Key Calculation** — anchor zoom at cursor position:

```swift
// When zoom changes, adjust content offset so the point
// under the cursor stays fixed
let cursorInContent = (cursorInView + currentOffset) / oldScale
let newOffset = cursorInContent * newScale - cursorInView
```

### 5.4 Quick Navigation

**Keyboard Shortcuts**:
| Key | Action |
|-----|--------|
| `Space` / `→` | Next image (下一张) |
| `Shift+Space` / `←` | Previous image (上一张) |
| `↑` / `↓` | Scroll image when zoomed in |
| `Escape` | Return to grid view |
| `F` | Fit to window |

**Trackpad**: Detect swipe left/right gesture to navigate

**Boundary Behavior**: At the last image, pressing next shows a brief hint "已是最后一张"; same for first image "已是第一张". No looping.

### 5.5 RAW Format Support

**Loading Strategy** (two-phase):

1. **Thumbnail** (fast): Extract embedded JPEG preview from RAW file using `CGImageSource` thumbnail options. Used for grid view.

```swift
let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
let options: [CFString: Any] = [
    kCGImageSourceThumbnailMaxPixelSize: 512,
    kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
    kCGImageSourceCreateThumbnailWithTransform: true
]
let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
```

2. **Full decode** (async): Use `CIRAWFilter` with RAW 9 decoder for full-quality viewing.

```swift
func loadFullRAW(url: URL) async throws -> NSImage {
    let rawFilter = CIRAWFilter(imageURL: url)!

    if rawFilter.supportedDecoderVersions.contains(.version9) {
        rawFilter.decoderVersion = .version9
    }

    // Use scaleFactor for display size (not full sensor resolution)
    rawFilter.scaleFactor = displayScaleFactor

    let context = CIContext(options: [.cacheIntermediates: true])
    guard let ciImage = rawFilter.outputImage,
          let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
        throw ImageLoadError.decodeFailed
    }

    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
}
```

**Unsupported Formats**: Show a placeholder image with text "不支持的格式" and the file extension.

---

## 6. UI Design Guidelines

- **Style**: Native macOS SwiftUI — follows system dark/light mode automatically
- **Sidebar**: `NavigationSplitView` with `.sidebar` column style
- **Grid**: `LazyVGrid` with adaptive columns `GridItem(.adaptive(minimum: 120))`
- **Viewer Background**: Dark background (`Color.black`) for full-size viewing
- **Status Bar**: Bottom bar showing file name, index (第 X / Y 张), zoom percentage
- **Window**: Resizable, minimum size 800×600, remember last position/size
- **All text in Chinese**: buttons, labels, menus, tooltips, error messages

---

## 7. Verification Checklist

- [ ] Click "导入文件夹" → select a folder → images appear in grid
- [ ] Nested subfolders appear in sidebar tree, expandable
- [ ] Click a thumbnail → enters full-size viewer
- [ ] Scroll wheel zooms at cursor position, not center
- [ ] Drag to pan when zoomed in
- [ ] Double-click resets zoom to fit-to-window
- [ ] Space / → key shows next image
- [ ] Shift+Space / ← key shows previous image
- [ ] Escape returns to grid view
- [ ] Quit and reopen → "最近打开" shows previous folders
- [ ] Click history item → reopens folder correctly
- [ ] RAW files (CR2, NEF, ARW) display thumbnails in grid
- [ ] RAW files render at full quality in viewer (RAW 9 if supported)
- [ ] Unsupported format shows placeholder with "不支持的格式"
- [ ] Dark mode and light mode both work correctly
- [ ] All UI text is in Chinese
