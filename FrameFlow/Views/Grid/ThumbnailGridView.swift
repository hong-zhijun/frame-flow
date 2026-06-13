import SwiftUI

struct ThumbnailGridView: View {
    @Environment(AppState.self) private var appState
    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            starFilterBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(appState.filteredImages.enumerated()), id: \.element.id) { index, item in
                        ThumbnailCell(item: item)
                            .onTapGesture {
                                appState.selectImage(at: index)
                            }
                    }
                }
                .padding(12)
            }
        }
    }

    private var starFilterBar: some View {
        @Bindable var state = appState
        return HStack(spacing: 8) {
            Text("星级")
                .font(.caption)
                .foregroundStyle(.secondary)

            starFilterButton(label: "全部", value: 0)

            let available = appState.availableStarRatings
            if available.contains(0) {
                starFilterButton(label: "无星", value: -1)
            }
            ForEach(available.filter { $0 > 0 }, id: \.self) { star in
                starFilterButton(
                    label: "\(star)星",
                    value: star,
                    icon: "star.fill"
                )
            }

            if appState.availableFormats.count > 1 {
                Divider()
                    .frame(height: 14)

                Text("格式")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                formatFilterButton(label: "全部", category: nil)

                ForEach(appState.availableFormats, id: \.self) { category in
                    formatFilterButton(label: category.label, category: category)
                }
            }

            Spacer()

            Text("\(appState.filteredImages.count) / \(appState.images.count) 张")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatFilterButton(label: String, category: ImageItem.FormatCategory?) -> some View {
        let isActive = appState.formatFilter == category
        return Button {
            appState.formatFilter = category
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(isActive ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func starFilterButton(label: String, value: Int, icon: String? = nil) -> some View {
        Button {
            appState.starFilter = value
            appState.statusMessage = value == 0
                ? "共 \(appState.images.count) 张图片"
                : "\(value)星: \(appState.filteredImages.count) 张"
        } label: {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(appState.starFilter == value ? Color.accentColor.opacity(0.2) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(appState.starFilter == value ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
