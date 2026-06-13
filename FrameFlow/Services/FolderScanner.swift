import Foundation

actor FolderScanner {
    func scan(url: URL, includeSubfolders: Bool = true) -> FolderNode {
        let fm = FileManager.default
        var children: [FolderNode] = []
        var images: [ImageItem] = []

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return FolderNode(url: url, name: url.lastPathComponent, children: [], images: [])
        }

        var subdirectories: [URL] = []
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey]) else {
                continue
            }

            if resourceValues.isDirectory == true {
                enumerator.skipDescendants()
                if includeSubfolders {
                    subdirectories.append(fileURL)
                }
            } else if resourceValues.isRegularFile == true, SupportedFormats.isSupported(fileURL) {
                images.append(ImageItem(url: fileURL))
            }
        }

        if includeSubfolders {
            for subdir in subdirectories.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                let childNode = scan(url: subdir, includeSubfolders: true)
                if childNode.imageCount > 0 {
                    children.append(childNode)
                }
            }
        }

        return FolderNode(
            url: url,
            name: url.lastPathComponent,
            children: children,
            images: images
        )
    }
}
