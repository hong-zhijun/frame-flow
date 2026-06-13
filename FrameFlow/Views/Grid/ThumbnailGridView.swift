import SwiftUI

struct ThumbnailGridView: View {
    @Environment(AppState.self) private var appState
    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(appState.images.enumerated()), id: \.element.id) { index, item in
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
