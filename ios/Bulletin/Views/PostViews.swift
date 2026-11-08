import SwiftUI

struct PostView: View {
    let post: Post

    var body: some View {
        switch post.kind {
        case .photo(let caption):
            PhotoPost(caption: caption, rotation: post.rotation)
        case .sticky(let text):
            StickyPost(text: text, rotation: post.rotation, isPromptAnswer: post.isPromptAnswer, isClipped: post.isClipped)
        case .journal(let title, let body):
            JournalPost(title: title, text: body, rotation: post.rotation, isPromptAnswer: post.isPromptAnswer, isClipped: post.isClipped)
        }
    }
}

/// The seeded "photo" from the design: a color block with a caption slip.
private struct PhotoPost: View {
    let caption: String
    let rotation: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color("Sticky"))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                .frame(width: 149.6, height: 149.6)
                .rotationEffect(.degrees(rotation))
                .overlay(alignment: .top) { Pushpin().offset(y: -4).rotationEffect(.degrees(rotation)) }

            Text(caption)
                .font(Typo.pixel(14))
                .foregroundStyle(.black)
                .padding(10)
                .background(.white)
                .overlay(Rectangle().strokeBorder(.black.opacity(0.15), lineWidth: 0.75))
                .rotationEffect(.degrees(rotation))
                .offset(x: 3.5, y: 85.7)
        }
        .frame(width: 149.6, height: 185, alignment: .top)
    }
}

/// A new sticky note. Lands with a little spring, and the pin drops in after it.
private struct StickyPost: View {
    let text: String
    let rotation: Double
    let isPromptAnswer: Bool
    let isClipped: Bool

    @State private var landed = false

    var body: some View {
        Text(text)
            .font(Typo.pixel(14))
            .lineSpacing(3)
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .frame(width: 132, alignment: .leading)
            .frame(minHeight: 96, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .background(Color("Sticky"), in: RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
            .overlay(alignment: .top) {
                Attachment(isClipped: isClipped)
                    .offset(y: landed ? -4 : -26)
                    .scaleEffect(landed ? 1 : 1.6)
                    .opacity(landed ? 1 : 0)
            }
            .overlay(alignment: .bottomTrailing) {
                if isPromptAnswer { PromptTag().offset(x: 6, y: 8) }
            }
            .rotationEffect(.degrees(landed ? rotation : rotation + 6))
            .scaleEffect(landed ? 1 : 0.88)
            .offset(y: landed ? 0 : -18)
            .opacity(landed ? 1 : 0)
            .onAppear {
                withAnimation(.spring(duration: 0.5, bounce: 0.35)) { landed = true }
            }
    }
}

struct Pushpin: View {
    var body: some View {
        Circle()
            .fill(Color(red: 0.976, green: 0.176, blue: 0.176))
            .overlay(Circle().strokeBorder(Color(red: 0.612, green: 0.047, blue: 0.047), lineWidth: 0.75))
            .frame(width: 9.5, height: 9.5)
    }
}

struct PromptTag: View {
    var body: some View {
        Text("prompt")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.white, in: Capsule())
            .overlay(Capsule().strokeBorder(.black.opacity(0.15), lineWidth: 0.75))
    }
}


/// Pushpin for things added the same day, paperclip for things added to a past day.
struct Attachment: View {
    let isClipped: Bool

    var body: some View {
        if isClipped {
            Image(systemName: "paperclip")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color(white: 0.42))
                .rotationEffect(.degrees(-12))
                .offset(y: -8)   // hangs on the top edge, clear of the text
                .accessibilityLabel("Added later")
        } else {
            Pushpin()
        }
    }
}

/// A long entry on the board: a folded note with an optional title, a snippet, and a read time.
private struct JournalPost: View {
    let title: String
    let text: String
    let rotation: Double
    let isPromptAnswer: Bool
    let isClipped: Bool

    @State private var landed = false

    private var readMinutes: Int { max(1, text.split(separator: " ").count / 200) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // No title typed means no title shown: just the start of the entry.
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineLimit(2)
            }
            Text(text)
                .font(Typo.pixel(12))
                .foregroundStyle(.black.opacity(0.7))
                .lineLimit(title.isEmpty ? 5 : 3)
            Text("\(readMinutes) min read")
                .font(.system(size: 11))
                .foregroundStyle(.black.opacity(0.45))
                .padding(.top, 2)
        }
        .foregroundStyle(.black)
        .padding(14)
        .frame(width: 160, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 2))
        .overlay(alignment: .topTrailing) { FoldedCorner() }
        .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
        .overlay(alignment: .top) { Attachment(isClipped: isClipped).offset(y: -4) }
        .overlay(alignment: .bottomTrailing) { if isPromptAnswer { PromptTag().offset(x: 6, y: 8) } }
        .rotationEffect(.degrees(landed ? rotation : rotation + 5))
        .scaleEffect(landed ? 1 : 0.9)
        .opacity(landed ? 1 : 0)
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.3)) { landed = true } }
    }
}

private struct FoldedCorner: View {
    var body: some View {
        Path { p in
            p.move(to: .zero); p.addLine(to: CGPoint(x: 16, y: 16)); p.addLine(to: CGPoint(x: 0, y: 16)); p.closeSubpath()
        }
        .fill(Color(white: 0.9))
        .frame(width: 16, height: 16)
        .shadow(color: .black.opacity(0.1), radius: 1, x: -1, y: 1)
    }
}
