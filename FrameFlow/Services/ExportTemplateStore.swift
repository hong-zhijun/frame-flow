import Foundation

@MainActor @Observable
final class ExportTemplateStore {
    private(set) var templates: [ExportTemplate] = []
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("FrameFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("export-templates.json")
        load()
    }

    func save(_ template: ExportTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        persist()
    }

    func delete(id: UUID) {
        templates.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ExportTemplate].self, from: data) else { return }
        templates = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(templates) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
