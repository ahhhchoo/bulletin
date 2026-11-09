import SwiftUI

struct PostView: View {
    let post: Post
    /// false for copies that are already on screen (the opened card, drag previews): no landing animation.
    var animated = true
    /// 1 = tilted as on the board, 0 = flat. The opened card animates this to straighten up.
    var tilt = 1.0

    var body: some View {
        let rotation = post.rotation * tilt
        switch post.kind {
        case .photo(let caption):
            PhotoPost(caption: caption, rotation: rotation, image: post.image, isPromptAnswer: post.isPromptAnswer)
        case .sticky(let text):
            StickyPost(text: text, rotation: rotation, isPromptAnswer: post.isPromptAnswer,
                       isClipped: post.isClipped, addedLabel: post.addedLabel, animated: animated)
        case .journal(let title, let body):
            JournalPost(title: title, text: body, rotation: rotation, isPromptAnswer: post.isPromptAnswer,
                        isClipped: post.isClipped, addedLabel: post.addedLabel, animated: animated)
        }
    }
}

/// A photo pinned like a polaroid: the picture with a white border, and a caption slip across its bottom edge.
/// The pin is as wide as always, and as tall as the picture needs: a portrait photo makes a taller pin, a
/// landscape one a shorter pin. Seed photos have no image, so they show the placeholder color block.
private struct PhotoPost: View {
    let caption: String
    let rotation: Double
    var image: PostImage?
    var isPromptAnswer = false

    private var width: CGFloat { PhotoMetrics.pinWidth }
    private var height: CGFloat { width / (image?.pinAspect ?? 1) }

    var body: some View {
        ZStack {
            picture
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                .rotationEffect(.degrees(rotation))
                .overlay(alignment: .top) { Pushpin().offset(y: -4).rotationEffect(.degrees(rotation)) }
                .overlay(alignment: .topLeading) { if isPromptAnswer { PromptTag().offset(x: 4, y: -8) } }

            if !caption.isEmpty {
                Text(caption)
                    .font(Typo.pixel(14))
                    .foregroundStyle(.black)
                    .padding(10)
                    .background(.white)
                    .overlay(Rectangle().strokeBorder(.black.opacity(0.15), lineWidth: 0.75))
                    .rotationEffect(.degrees(rotation))
                    .offset(x: 3.5, y: height / 2 + 10.7)      // across the bottom edge, as in the design
            }
        }
        .frame(width: width, height: height + 35.4, alignment: .top)
    }

    @ViewBuilder private var picture: some View {
        if let image {
            Image(uiImage: image.uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Color("Sticky")
        }
    }
}

/// A new sticky note. Lands with a little spring, and the pin drops in after it.
private struct StickyPost: View {
    let text: String
    let rotation: Double
    let isPromptAnswer: Bool
    let isClipped: Bool
    var addedLabel: String?
    var animated = true

    @State private var didLand = false
    private var landed: Bool { didLand || !animated }

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
                Attachment(isClipped: isClipped, addedLabel: addedLabel)
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
                guard animated else { return }
                withAnimation(.spring(duration: 0.5, bounce: 0.35)) { didLand = true }
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
/// Tap the paperclip to see when it was added.
struct Attachment: View {
    let isClipped: Bool
    var addedLabel: String?
    @State private var showWhen = false

    var body: some View {
        if isClipped {
            Button { showWhen = true } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(white: 0.42))
                    .rotationEffect(.degrees(-12))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(y: -8)   // hangs on the top edge, clear of the text
            .popover(isPresented: $showWhen) {
                Text("Added \(addedLabel ?? "later")")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityLabel("Added later")
            .accessibilityHint("Shows when it was added")
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
    var addedLabel: String?
    var animated = true

    @State private var didLand = false
    private var landed: Bool { didLand || !animated }

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
        .overlay(alignment: .top) { Attachment(isClipped: isClipped, addedLabel: addedLabel).offset(y: -4) }
        .overlay(alignment: .bottomTrailing) { if isPromptAnswer { PromptTag().offset(x: 6, y: 8) } }
        .rotationEffect(.degrees(landed ? rotation : rotation + 5))
        .scaleEffect(landed ? 1 : 0.9)
        .opacity(landed ? 1 : 0)
        .onAppear {
            guard animated else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { didLand = true }
        }
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
