import SwiftUI

/// The posts of one day, two across. A busy day folds its overflow into a stack; tapping the stack
/// fans everything out, and a "Stack back up" pill after the last post folds it again.
struct DayPosts: View {
    let posts: [Post]
    /// Indices into `posts` that are on screen right now, in posting order.
    let shown: [Int]
    /// How many posts are folded into the stack (0 = no stack).
    let stackedCount: Int
    let stackPreview: Post?
    let showPill: Bool
    let onExpand: () -> Void
    let onCollapse: () -> Void

    private enum Cell: Identifiable {
        case post(Post, index: Int)
        case stack

        var id: AnyHashable {
            switch self {
            case .post(let p, _): p.id
            case .stack: "stack"
            }
        }
    }

    private var cells: [Cell] {
        var out = shown.map { Cell.post(posts[$0], index: $0) }
        if stackedCount > 0 { out.append(.stack) }
        return out
    }

    /// Where the stack sits in the two-column layout. Posts fan out from, and fly back to, this cell.
    private var stackSlot: Int { shown.count }

    private let columnGap: CGFloat = 0
    private let rowGap: CGFloat = 18
    /// Left column starts at 49 and the right at 210 (BRD-01), so the left cell is 161 wide.
    private func cellWidth(_ column: Int) -> CGFloat { column == 0 ? 161 : 140 }

    var body: some View {
        let all = cells
        let rows = stride(from: 0, to: all.count, by: 2).map { Array(all[$0..<min($0 + 2, all.count)]) }

        VStack(alignment: .leading, spacing: rowGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: columnGap) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { column, cell in
                        cellView(cell)
                            .frame(width: cellWidth(column), alignment: .leading)
                            .padding(.top, column == 1 ? 7 : 0)      // the right-hand note hangs a little lower
                    }
                }
            }

            if showPill {
                StackBackUpPill(action: onCollapse)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
            }
        }
        .padding(.leading, 5)
    }

    @ViewBuilder
    private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .post(let post, let index):
            PostCell(post: post)
                .id(post.id)
                .transition(FanOut(from: offsetFromStack(to: index), tilt: index.isMultiple(of: 2) ? 8 : -8))
        case .stack:
            StackCard(count: stackedCount, preview: stackPreview, action: onExpand)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    /// Where the stack is, relative to the slot a post lands in once the day is opened.
    private func offsetFromStack(to index: Int) -> CGSize {
        let dCol = CGFloat((stackSlot % 2) - (index % 2))
        let dRow = CGFloat((stackSlot / 2) - (index / 2))
        return CGSize(width: dCol * 161, height: dRow * 190)
    }
}

// MARK: - Motion

/// A post leaves the stack by flying out to its slot, and returns by flying back in.
struct FanOut: Transition {
    var from: CGSize
    var tilt: Double

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.55)
            .offset(phase.isIdentity ? .zero : from)
            .rotationEffect(.degrees(phase.isIdentity ? 0 : tilt))
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

// MARK: - Stack

/// The pile that holds a busy day's overflow: a few layered notes, blurred, with a count and "Expand".
struct StackCard: View {
    let count: Int
    let preview: Post?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.5))
                    .frame(width: 140, height: 160)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    .rotationEffect(.degrees(3.4))
                    .offset(x: 4, y: 12)
                RoundRectangle(fill: Color(white: 0.957))
                    .rotationEffect(.degrees(1.5))
                    .offset(x: 5, y: 5)
                frontNote
            }
            .frame(width: 140, height: 160)
            .overlay(alignment: .center) { ExpandPill(count: count) }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(count) more posts")
        .accessibilityHint("Expand this day")
    }

    private var frontNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(previewTitle)
                .font(.system(size: 15, weight: .bold, design: .serif))
            Text(previewBody)
                .font(Typo.pixel(11.5))
                .foregroundStyle(.black.opacity(0.6))
                .lineLimit(4)
        }
        .foregroundStyle(.black)
        .blur(radius: 3)
        .padding(13)
        .frame(width: 140, height: 160, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }

    private var previewTitle: String {
        if case .journal(let title, _)? = preview?.kind, !title.isEmpty { return title }
        return "more from this day"
    }

    private var previewBody: String {
        switch preview?.kind {
        case .journal(_, let body)?: body
        case .sticky(let text)?: text
        case .photo(let caption)?: caption
        case nil: ""
        }
    }
}

private struct RoundRectangle: View {
    let fill: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.5))
            .frame(width: 140, height: 160)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
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

private struct ExpandPill: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("Expand")
            Text("+\(count)").foregroundStyle(.black.opacity(0.5))
        }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.black.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

/// Shown after the last post of an opened day. The only way back to the stack: no surprises.
struct StackBackUpPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Stack back up", systemImage: "chevron.up")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black)
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .padding(.vertical, 9)
                .background(.black.opacity(0.06), in: Capsule())
                .overlay(Capsule().strokeBorder(.black.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}
