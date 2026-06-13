import SwiftUI

struct StarRatingView: View {
    let rating: Int
    let maxRating: Int
    let size: CGFloat
    var onRate: ((Int) -> Void)?

    init(rating: Int, maxRating: Int = 5, size: CGFloat = 14, onRate: ((Int) -> Void)? = nil) {
        self.rating = rating
        self.maxRating = maxRating
        self.size = size
        self.onRate = onRate
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index <= rating ? .yellow : .gray.opacity(0.5))
                    .onTapGesture {
                        if index == rating {
                            onRate?(0)
                        } else {
                            onRate?(index)
                        }
                    }
            }
        }
    }
}
