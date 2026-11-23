import SwiftUI

/// "Currently into": just the words, big, like a headline. Same on every board, so it stays calm.
struct BigWord: View {
    let label: String
    let value: String
    var size: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Typo.scaled(11, .medium, relativeTo: .caption))
                .foregroundStyle(.black.opacity(0.5))
            Text(value)
                .font(Typo.scaled(size, .medium, relativeTo: .title3))
                .foregroundStyle(.black)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
    }
}

struct ChatAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    var destructive = false
    let run: () -> Void
}

/// The monthly prompt as a little conversation: the app asks, you reply. The answer can be a note,
/// a photo or a post that was already on the board, and shows as a short preview.
struct PromptChat: View {
    let question: String
    var answer: Post?
    /// Your own board shows a dashed "answer" bubble when you haven't replied yet.
    var allowsAnswering = false
    let onAnswer: () -> Void
    var actions: [ChatAction] = []

    private static let pink = Color("DayPink")

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(question)
                .font(Typo.scaled(12, .regular, relativeTo: .footnote))
                .foregroundStyle(.black.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.white, in: Self.bubble(tail: .leading))
                .accessibilityLabel("This month’s prompt: \(question)")

            HStack(spacing: 0) {
                Spacer(minLength: 24)
                reply
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var reply: some View {
        if let answer {
            Button(action: onAnswer) {
                HStack(spacing: 6) {
                    if case .photo = answer.kind { thumb(answer) }
                    Text(Self.summary(of: answer)).lineLimit(1)
                }
                .font(Typo.scaled(12, .medium, relativeTo: .footnote))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Self.pink, in: Self.bubble(tail: .trailing))
            }
            .buttonStyle(PressableStyle())
            .contextMenu {
                ForEach(actions) { a in
                    Button(a.title, systemImage: a.icon, role: a.destructive ? .destructive : nil, action: a.run)
                }
            }
            .accessibilityLabel("The answer: \(Self.summary(of: answer))")
        } else if allowsAnswering {
            Button(action: onAnswer) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text("answer")
                }
                .font(Typo.scaled(12, .medium, relativeTo: .footnote))
                .foregroundStyle(Self.pink)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Self.bubble(tail: .trailing).stroke(Self.pink.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Answer the prompt")
        }
    }

    private func thumb(_ post: Post) -> some View {
        Group {
            if let image = post.image?.uiImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color("Sticky")
            }
        }
        .frame(width: 20, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.white, lineWidth: 1.5))
    }

    private enum Tail { case leading, trailing }

    /// A rounded bubble with one squarer corner at the bottom, on the side it is "spoken" from.
    private static func bubble(tail: Tail) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: tail == .leading ? 3 : 12,
                               bottomTrailingRadius: tail == .trailing ? 3 : 12, topTrailingRadius: 12,
                               style: .continuous)
    }

    static func summary(of post: Post) -> String {
        switch post.kind {
        case .photo(let caption): caption.isEmpty ? "a photo" : caption
        case .sticky(let text): text
        case .journal(let title, let body): title.isEmpty ? body : title
        }
    }
}

/// The little page indicator under a pair of cards.
struct PageDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(.black.opacity(i == current ? 0.2 : 0.1))
                    .frame(width: i == current ? 16 : 7, height: 7)
            }
        }
        .animation(.snappy(duration: 0.25), value: current)
        .accessibilityHidden(true)
    }
}
