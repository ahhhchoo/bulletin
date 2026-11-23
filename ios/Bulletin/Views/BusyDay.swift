import SwiftUI

/// The posts of one day, two across. Every post is shown; tapping the day's date folds the whole day away (see `DayRow`).
struct DayPosts: View {
    let posts: [Post]

    private let columnGap: CGFloat = 0
    private let rowGap: CGFloat = 18
    /// Left column starts at 49 and the right at 210 (BRD-01), so the left cell is 161 wide.
    private func cellWidth(_ column: Int) -> CGFloat { column == 0 ? 161 : 140 }

    var body: some View {
        let rows = stride(from: 0, to: posts.count, by: 2).map { Array(posts[$0..<min($0 + 2, posts.count)]) }

        VStack(alignment: .leading, spacing: rowGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: columnGap) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { column, post in
                        PostCell(post: post)
                            .id(post.id)
                            .frame(width: cellWidth(column), alignment: .leading)
                            .padding(.top, column == 1 ? 7 : 0)      // the right-hand note hangs a little lower
                    }
                }
            }
        }
        .padding(.leading, 5)
    }
}

struct CountBadge: View {
    let count: Int
    var body: some View {
        Text("+\(count)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(minWidth: 28, minHeight: 24)
            .background(.black, in: Capsule())
    }
}
