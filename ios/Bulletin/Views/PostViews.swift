import SwiftUI

/// Position of the faded sheet that peeks out behind a journal entry.
struct BackSheet {
    var rotation: Double, x: CGFloat, y: CGFloat
    static let board = BackSheet(rotation: 3.4, x: 4, y: 28)
    static let intro = BackSheet(rotation: 2.4, x: 2, y: 10)
}

struct PostView: View {
    let post: Post
    /// false for copies that are already on screen (the opened card, drag previews): no landing animation.
    var animated = true
    /// 1 = tilted as on the board, 0 = flat. The opened card animates this to straighten up.
    var tilt = 1.0
    /// On the board a photo's caption shows two lines at most; the opened photo shows all of it.
    var fullCaption = false
    /// The caption's size on screen. The opened photo is scaled up, so it passes a smaller number to land on 14.
    var captionSize: CGFloat?
    /// The opened photo brings its caption in after it has grown.
    var captionVisible = true
    /// Where the faded sheet behind a long entry sits. The default is the board's; the intro tucks it in closer.
    var backSheet = BackSheet.board

    var body: some View {
        let rotation = post.rotation * tilt
        switch post.kind {
        case .photo(let caption):
            PhotoPost(caption: caption, rotation: rotation, image: post.image, isPromptAnswer: post.isPromptAnswer, fullCaption: fullCaption,
                      captionSize: captionSize, captionVisible: captionVisible)
        case .sticky(let text):
            StickyPost(text: text, color: post.stickyColor, rotation: rotation, isPromptAnswer: post.isPromptAnswer,
                       isClipped: post.isClipped, addedLabel: post.addedLabel, animated: animated)
        case .journal(let title, let body):
            JournalPost(title: title, text: body, rotation: rotation, isPromptAnswer: post.isPromptAnswer,
                        isClipped: post.isClipped, addedLabel: post.addedLabel, animated: animated, backSheet: backSheet)
        }
    }
}

/// A photo as designed in BRD-01: 128 wide with a white edge and rounded corners, a small pin, and a caption slip
/// across its bottom edge. The height follows the picture's shape. Seed photos have no image, so they show a color block.
private struct PhotoPost: View {
    let caption: String
    let rotation: Double
    var image: PostImage?
    var isPromptAnswer = false
    var fullCaption = false
    var captionSize: CGFloat?
    var captionVisible = true

    private var width: CGFloat { PhotoMetrics.pinWidth }
    private var height: CGFloat { width / (image?.pinAspect ?? 1) }

    private var captionFont: CGFloat { captionSize ?? 10 }

    /// Extra height for a caption that runs onto a second line on the board. The opened photo adds none:
    /// its caption just hangs below, so the photo's size never depends on how much was written.
    private var extraCaptionHeight: CGFloat {
        guard !fullCaption else { return 0 }
        let lines = min(2, max(1, (caption.count + PhotoMetrics.captionCharsPerLine - 1) / PhotoMetrics.captionCharsPerLine))
        return CGFloat(lines - 1) * 13
    }

    /// The picture hardly tilts; the slip carries the tilt.
    private var photoTilt: Double { rotation * 0.3 }

    var body: some View {
        ZStack(alignment: .top) {
            picture
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                .rotationEffect(.degrees(photoTilt))
                .overlay(alignment: .top) { Pushpin().offset(y: -1) }      // on the top edge, centered, whichever way the photo leans
                .overlay(alignment: .topLeading) { if isPromptAnswer { PromptTag().offset(x: 4, y: -8) } }

            if !caption.isEmpty {
                Text(caption)
                    .font(Typo.pixel(captionFont))
                    .foregroundStyle(.black)
                    .lineLimit(fullCaption ? nil : 2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .padding(10)
                    .background(.white)
                    .overlay(Rectangle().strokeBorder(.black.opacity(0.15), lineWidth: 0.75))
                    .rotationEffect(.degrees(rotation))
                    .opacity(captionVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.25).delay(captionVisible ? 0.25 : 0), value: captionVisible)
                    .offset(x: 9, y: height - 9.8)      // the slip's top edge sits just inside the picture's bottom edge
            }
        }
        .frame(width: width, height: height + 25.4 + extraCaptionHeight, alignment: .top)
    }

    /// Feeds and tiles use the small picture. Only an opened photo (`fullCaption`) loads the big one, or plays the GIF.
    @ViewBuilder private var picture: some View {
        if let image {
            if fullCaption {
                FullPicture(image: image)
            } else {
                FeedPicture(image: image)
            }
        } else {
            Color("Sticky")
        }
    }
}

/// The seven sticky colors from the design: the paper itself and the darker flap folded over its corner.
enum StickyColor: String, CaseIterable, Hashable, Identifiable {
    case yellow, green, red, blue, periwinkle, purple, orange
    var id: String { rawValue }

    /// The paper.
    var body: Color {
        switch self {
        case .yellow: Color(hex: 0xF4E8C4)
        case .green: Color(hex: 0xD1F4C4)
        case .red: Color(hex: 0xFFCFCF)
        case .blue: Color(hex: 0xCAECFF)
        case .periwinkle: Color(hex: 0xCAD6FF)
        case .purple: Color(hex: 0xEAD5FF)
        case .orange: Color(hex: 0xFFDDC0)
        }
    }

    /// The folded corner.
    var flap: Color {
        switch self {
        case .yellow: Color(hex: 0xF4CB52)
        case .green: Color(hex: 0x9EE086)
        case .red: Color(hex: 0xF08383)
        case .blue: Color(hex: 0x7CC1F2)
        case .periwinkle: Color(hex: 0x7C98F2)
        case .purple: Color(hex: 0xB484E7)
        case .orange: Color(hex: 0xECAE82)
        }
    }

    var label: String { rawValue }

    /// What the color is called when you pick it.
    var nickname: String {
        switch self {
        case .yellow: "banana"
        case .green: "celery"
        case .red: "shrimp"
        case .blue: "shark"
        case .periwinkle: "urchin"
        case .purple: "grape"
        case .orange: "orange"
        }
    }
}

extension Color {
    /// 0xRRGGBB
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

enum Paper {
    static let yellow = Color(red: 0.957, green: 0.796, blue: 0.322)      // #F4CB52
    /// The sticky's body: #F4CB52 at 30% over the board's paper, mixed down to one solid color so it stays opaque
    /// when it is lifted off the board (opened, or being written).
    static let stickyFill = Color(red: 0.960, green: 0.911, blue: 0.769)
    static let width: CGFloat = 140
    static let minHeight: CGFloat = 160
}

/// A card with its bottom-right corner cut off, as in BRD-01. `PaperFold` is the flap that lies over the cut.
struct CutCornerShape: Shape {
    /// 1 = the 140 x 160 card on the board. Bigger paper (the composer) scales the cut and the corners with it.
    var scale: CGFloat = 1

    func path(in r: CGRect) -> Path {
        var p = Path()
        let c: CGFloat = 12 * scale
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 25 * scale))
        p.addLine(to: CGPoint(x: r.maxX - 27.344 * scale, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

struct PaperFold: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = r.width * 0.45      // 12 on the 26.6 flap
        p.move(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A new sticky note: soft yellow with a folded corner. Lands with a little spring.
private struct StickyPost: View {
    let text: String
    var color: StickyColor = .yellow
    let rotation: Double
    let isPromptAnswer: Bool
    let isClipped: Bool
    var addedLabel: String?
    var animated = true

    @State private var didLand = false
    private var landed: Bool { didLand || !animated }

    var body: some View {
        Text(text)
            .font(Typo.scaled(14, .semibold, relativeTo: .subheadline))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .frame(width: Paper.width - 26, alignment: .topLeading)
            .padding(.horizontal, 13)
            .padding(.vertical, 16)
            .frame(width: Paper.width, alignment: .topLeading)
            .frame(minHeight: Paper.minHeight, alignment: .topLeading)
            .background(CutCornerShape().fill(color.body))
            .overlay(alignment: .bottomTrailing) {
                PaperFold().fill(color.flap).frame(width: 26.6, height: 26.6).offset(x: 0, y: 0)
            }
            .overlay(alignment: .top) {
                if isClipped {
                    Attachment(isClipped: true, addedLabel: addedLabel)
                        .offset(y: landed ? -4 : -26).opacity(landed ? 1 : 0)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isPromptAnswer { PromptTag().offset(x: 6, y: 8) }
            }
            .rotationEffect(.degrees(landed ? 0 : 6))
            .scaleEffect(landed ? 1 : 0.88)
            .offset(y: landed ? 0 : -18)
            .opacity(landed ? 1 : 0)
            .onAppear {
                guard animated else { return }
                withAnimation(.spring(duration: 0.5, bounce: 0.35)) { didLand = true }
            }
    }
}

/// The pin: a solid red dot with a soft drop shadow.
struct Pushpin: View {
    var body: some View {
        Circle()
            .fill(Color(red: 0.976, green: 0.176, blue: 0.176))      // #F92D2D
            .frame(width: 8, height: 8)
            .shadow(color: Color(red: 0.047, green: 0.047, blue: 0.051).opacity(0.1), radius: 2, y: 1)
            .shadow(color: Color(red: 0.047, green: 0.047, blue: 0.051).opacity(0.05), radius: 2, y: 1)
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

/// A long entry on the board: a white card with a folded corner, a title, a snippet and a read time, with a
/// faded sheet peeking out behind it.
private struct JournalPost: View {
    let title: String
    let text: String
    let rotation: Double
    let isPromptAnswer: Bool
    let isClipped: Bool
    var addedLabel: String?
    var animated = true
    var backSheet = BackSheet.board

    @State private var didLand = false
    private var landed: Bool { didLand || !animated }

    private var readMinutes: Int { max(1, text.split(separator: " ").count / 200) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // No title typed means no title shown: just the start of the entry.
            if !title.isEmpty {
                Text(title)
                    .font(Typo.scaled(14, .semibold, relativeTo: .subheadline))
                    .lineLimit(2)
                    .padding(.bottom, 13)
            }
            Text(text)
                .font(Typo.scaled(12, .medium, relativeTo: .caption))
                .foregroundStyle(.black.opacity(0.6))
                .lineLimit(title.isEmpty ? 7 : 4)
            Spacer(minLength: 8)
            Text("\(readMinutes) min read")
                .font(Typo.scaled(12, .regular, relativeTo: .caption))
                .foregroundStyle(.black.opacity(0.6))
        }
        .foregroundStyle(.black)
        .frame(width: Paper.width - 26, alignment: .topLeading)
        .padding(.horizontal, 13)
        .padding(.vertical, 14)
        .frame(width: Paper.width, height: Paper.minHeight, alignment: .topLeading)
        .background(CutCornerShape().fill(.white))
        .overlay(alignment: .bottomTrailing) {
            PaperFold().fill(.black.opacity(0.05)).frame(width: 26.6, height: 26.6)
        }
        .shadow(color: Color(red: 0.047, green: 0.047, blue: 0.051).opacity(0.1), radius: 2, y: 1)
        .shadow(color: Color(red: 0.047, green: 0.047, blue: 0.051).opacity(0.05), radius: 2, y: 1)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.5))
                .frame(width: Paper.width, height: Paper.minHeight)
                .shadow(color: Color(red: 0.047, green: 0.047, blue: 0.051).opacity(0.05), radius: 2, y: 1)
                .rotationEffect(.degrees(backSheet.rotation))
                .offset(x: backSheet.x, y: backSheet.y)
        }
        .overlay(alignment: .top) {
            if isClipped { Attachment(isClipped: true, addedLabel: addedLabel).offset(y: -4) }
        }
        .overlay(alignment: .bottomTrailing) { if isPromptAnswer { PromptTag().offset(x: 6, y: 8) } }
        .scaleEffect(landed ? 1 : 0.9)
        .opacity(landed ? 1 : 0)
        .onAppear {
            guard animated else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { didLand = true }
        }
    }
}

