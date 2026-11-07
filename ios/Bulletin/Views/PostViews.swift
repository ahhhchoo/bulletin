import SwiftUI

struct PostView: View {
    let post: Post

    var body: some View {
        switch post.kind {
        case .photo(let caption):
            PhotoPost(caption: caption, rotation: post.rotation)
        case .sticky(let text):
            StickyPost(text: text, rotation: post.rotation, isPromptAnswer: post.isPromptAnswer)
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
                Pushpin()
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
