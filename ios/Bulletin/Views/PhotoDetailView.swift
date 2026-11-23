import SwiftUI

/// A photo opened: from the "POST-comment" design. A flat black 70% backdrop, the photo big and portrait at the top,
/// a small caption slip and the date under it. Friends' notes are not hidden in a drawer: they are taped paper cards
/// that pile up as you scroll, one landing on the last. The photo shrinks a little to make room for them.
struct PhotoDetailView: View {
    @Environment(NotesStore.self) private var store
    let post: Post
    /// Where the photo was on screen, so it grows from there. Nil: it grows from the middle.
    let origin: CGRect?
    let dayLabel: String?
    /// Your own photo (read, reply, tuck away) or a friend's (leave a note).
    let owner: Bool
    let friendName: String
    let onClose: () -> Void

    @State private var expanded = false
    @State private var offset: CGFloat = 0
    @State private var writing: Writing?

    private enum Writing: Identifiable, Equatable {
        case note
        case edit
        case reply(PostNote.ID)
        var id: String { switch self { case .note: "note"; case .edit: "edit"; case .reply(let i): i.uuidString } }
    }

    // from the design
    private static let photoWidth: CGFloat = 262.281
    private static let photoHeight: CGFloat = 327.852
    private static let photoTop: CGFloat = 94
    private static let step: CGFloat = 230          // how far you scroll for each note

    private var notes: [PostNote] { store.notes(post.id) }
    private var caption: String { if case .photo(let c) = post.kind { c } else { "" } }

    /// How far through the pile you are: 0 is the first note, `notes.count - 1` the last.
    private var progress: CGFloat { notes.count > 1 ? min(max(0, offset) / Self.step, CGFloat(notes.count - 1)) : 0 }
    private var topIndex: Int { min(max(0, Int(progress.rounded())), max(0, notes.count - 1)) }
    private var pull: CGFloat { max(0, -offset) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let p0 = min(1, progress)                          // the photo makes room during the first step
            let writingNow = writing != nil
            let shrink = writingNow ? 0.5 : 1 - 0.26 * ease(p0)
            let startScale = origin.map { $0.width / Self.photoWidth } ?? 0.5
            let startCenter = origin.map { CGPoint(x: $0.midX, y: $0.midY) } ?? CGPoint(x: w / 2, y: geo.size.height * 0.4)
            let top = writingNow ? 56 : Self.photoTop
            let center = CGPoint(x: w / 2, y: top + Self.photoHeight * shrink / 2 + (writingNow ? 0 : pull * 0.4))

            ZStack {
                Color.black.opacity(expanded ? 0.7 : 0)
                    .ignoresSafeArea()
                    .onTapGesture(perform: close)

                // the scrolling itself: tall and see-through, it only supplies the motion
                ScrollView {
                    Color.clear
                        .frame(height: geo.size.height + CGFloat(max(0, notes.count - 1)) * Self.step)
                        .contentShape(.rect)
                        .onTapGesture(perform: close)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, new in offset = new }
                .onScrollPhaseChange { _, phase in
                    if phase == .idle || phase == .decelerating, pull > 90 { close() }
                }
                .ignoresSafeArea()

                photoView
                    .frame(width: Self.photoWidth, height: Self.photoHeight)
                    .scaleEffect(expanded ? shrink : startScale)
                    .position(expanded ? center : startCenter)
                    .allowsHitTesting(false)

                captionAndDate(top: Self.photoTop + Self.photoHeight * shrink - 8 + pull * 0.4, shrink: shrink, p0: p0)
                    .opacity(writingNow ? 0 : 1)
                    .animation(.easeOut(duration: 0.2), value: writingNow)
                    .allowsHitTesting(false)

                pile(width: w, p0: p0)
                    .opacity(writingNow ? 0 : 1)
                    .animation(.easeOut(duration: 0.2), value: writingNow)

                if (!owner || notes.count > 1) && !writingNow { footer(height: geo.size.height) }

                if let writing { writer(writing).frame(width: w, height: geo.size.height).transition(.opacity) }
            }
            .animation(.spring(duration: 0.5, bounce: 0.2), value: expanded)
            .animation(.spring(duration: 0.5, bounce: 0.15), value: writingNow)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.selection, trigger: topIndex)
        .onAppear { expanded = true }
    }

    // MARK: photo

    private var photoView: some View {
        Group {
            if let image = post.image {
                // opened: the full picture, or the GIF playing
                FullPicture(image: image)
            } else {
                Color("Sticky")
            }
        }
        .frame(width: Self.photoWidth, height: Self.photoHeight)
        .clipShape(RoundedRectangle(cornerRadius: 24.589, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24.589, style: .continuous).strokeBorder(.white, lineWidth: 4.098))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }

    private func captionAndDate(top: CGFloat, shrink: CGFloat, p0: CGFloat) -> some View {
        VStack(spacing: 14) {
            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(10)
                    .frame(maxWidth: 300)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(.white)
                    .overlay(Rectangle().strokeBorder(.black.opacity(0.15), lineWidth: 0.75))
            }
            VStack(spacing: 2) {
                Text(post.postedAt.postStamp)
                if post.isClipped, let added = post.addedLabel { Text("Added \(added)") }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
            .opacity(Double(Swift.max(0, 1 - p0 * 1.3)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, top)
        .opacity(expanded ? 1 : 0)
        .animation(.easeOut(duration: 0.35).delay(expanded ? 0.3 : 0), value: expanded)
    }

    // MARK: the pile

    private static let tilts: [Double] = [-2.4, 1.8, -1.2, 2.6, -3]

    private func pile(width: CGFloat, p0: CGFloat) -> some View {
        let cardWidth = min(328, width - 74)
        let baseTop = 632 - (632 - 476) * ease(p0)          // where the top card rests
        return ZStack(alignment: .top) {
            if notes.isEmpty {
                EmptyStatePlaceholder(title: "No notes yet",
                                      intent: "Friends' notes land here once they leave one on this photo.")
                    .frame(width: cardWidth)
                    .offset(y: baseTop)
                    .opacity(expanded ? 1 : 0)
            }
            ForEach(Array(notes.enumerated()), id: \.element.id) { i, note in
                let enter = i == 0 ? 1 : min(1, max(0, progress - CGFloat(i - 1)))     // 0: below the screen, 1: landed
                let depth = max(0, progress - CGFloat(i))                                // notes that landed on top of this one
                let tilt = Self.tilts[i % Self.tilts.count]
                NoteCard(note: note, owner: owner)
                    .frame(width: cardWidth)
                    .rotationEffect(.degrees(tilt * Double(ease(enter)) + (i == 0 ? 0 : Double(1 - ease(enter)) * 7)))
                    .scaleEffect(1 - min(depth, 4) * 0.012)
                    .offset(x: (i.isMultiple(of: 2) ? -8 : 8) * ease(enter) * (i == 0 ? 0 : 1),
                            y: baseTop + (i == 0 ? 0 : (1 - ease(enter)) * 360))
                    .opacity(i == 0 ? (expanded ? 1 : 0) : Double(Swift.min(1, enter * 3)))
                    .animation(.spring(duration: 0.5, bounce: 0.25).delay(i == 0 && expanded ? 0.45 : 0), value: expanded)
                    .allowsHitTesting(false)
                    .overlay(alignment: .topTrailing) {
                        noteMenu(note)
                            .allowsHitTesting(i == topIndex && expanded)
                            .offset(x: -(width - cardWidth) / 2 + 0, y: baseTop + (i == 0 ? 0 : (1 - ease(enter)) * 360) + 6)
                    }
                    .zIndex(Double(i))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The little menu on the top card: reply or tuck away on your photo, take back a note you left.
    @ViewBuilder private func noteMenu(_ note: PostNote) -> some View {
        if owner || note.mine {
            Menu {
                if owner {
                    if note.reply == nil { Button("Reply", systemImage: "arrowshape.turn.up.left") { writing = .reply(note.id) } }
                    Button("Tuck away", systemImage: "tray.and.arrow.down", role: .destructive) {
                        withAnimation(.snappy) { store.tuck(note.id, on: post.id) }
                    }
                } else {
                    Button("Edit", systemImage: "pencil") { withAnimation(.snappy) { writing = .edit } }
                    Button("Take back", systemImage: "arrow.uturn.backward", role: .destructive) {
                        withAnimation(.snappy) { store.takeBack(on: post.id) }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.4))
                    .frame(width: 36, height: 28)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Note options")
        }
    }

    // MARK: count, hint and the way to leave a note

    private func footer(height: CGFloat) -> some View {
        VStack(spacing: 14) {
            Spacer()
            if !owner && !notes.contains(where: \.mine) {
                Button { withAnimation(.snappy) { writing = .note } } label: {
                    Text("Leave a note about this photo…")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
                        .frame(width: 328, height: 46)
                        .background(.white.opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
            if notes.count > 1 {
                VStack(spacing: 7) {
                    Text("scroll for more notes")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                        .opacity(Double(Swift.max(0, 1 - progress * 3)))
                    Text("\(topIndex + 1) of \(notes.count)")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.88))
                    HStack(spacing: 5) {
                        ForEach(notes.indices, id: \.self) { i in
                            Circle().fill(.white.opacity(i == topIndex ? 1 : 0.35)).frame(width: 6, height: 6)
                                .scaleEffect(i == topIndex ? 1.25 : 1)
                        }
                    }
                    .animation(.snappy(duration: 0.25), value: topIndex)
                }
                .allowsHitTesting(false)
            }
        }
        .padding(.bottom, 44)
        .frame(maxWidth: .infinity)
        .opacity(expanded ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.6), value: expanded)
    }

    private func writer(_ w: Writing) -> some View {
        NoteWriter(
            title: { switch w {
                case .reply(let id): "Reply to \(notes.first(where: { $0.id == id })?.by ?? "")"
                case .edit: "Edit your note to \(friendName)"
                case .note: "To \(friendName), about this photo" } }(),
            isReply: { if case .reply = w { true } else { false } }(),
            sendLabel: w == .edit ? "Save" : nil,
            initial: w == .edit ? (notes.first(where: \.mine)?.text ?? "") : "",
            onCancel: { withAnimation(.snappy) { writing = nil } },
            onSend: { text in
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                    switch w {
                    case .note: store.addMine(text, to: post.id)
                    case .edit: store.editMine(text, on: post.id)
                    case .reply(let id): store.reply(text, to: id, on: post.id)
                    }
                    writing = nil
                }
            })
    }

    // MARK: helpers

    private func close() {
        withAnimation(.spring(duration: 0.42, bounce: 0.12)) { expanded = false }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            onClose()
        }
    }

    private func ease(_ t: CGFloat) -> CGFloat { 1 - pow(1 - t, 3) }
}

// MARK: - a note, taped on

extension View {
    /// The paper of a note, from the design: a #F5F5F5 card with 18 pt corners, the "Blur + Shadow Big" style's two
    /// shadows (a tight one and a long soft one), and a strip of the tape from the design across its top edge.
    func notePaper(taped: Bool = true) -> some View {
        self
            .background(Color("Paper"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.09), radius: 5, y: 7)
            .shadow(color: .black.opacity(0.3), radius: 40, y: 40)
            .overlay(alignment: .top) {
                if taped { NoteTape().offset(x: 2.5, y: -26) }
            }
    }
}

/// The strip of tape from the design (77 x 34), as it is drawn there: turned over top to bottom.
struct NoteTape: View {
    var body: some View {
        Image("Tape")
            .resizable()
            .frame(width: 77, height: 34)
            .scaleEffect(x: 1, y: -1)
            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
            .accessibilityHidden(true)
    }
}

/// A friend's note as a paper card with a strip of tape: their words, their name and a dot in their color.
/// The owner's reply, if there is one, sits under it.
private struct NoteCard: View {
    let note: PostNote
    let owner: Bool

    private var dot: Color {
        if note.mine { return Color(red: 0.75, green: 0.91, blue: 0.85) }
        return Friend.names.firstIndex(of: note.by).map(Friend.color(at:)) ?? Color(white: 0.85)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(note.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 36)
            if let reply = note.reply {
                Text("You: \(reply)")
                    .font(.system(size: 11)).foregroundStyle(.black.opacity(0.55))
                    .padding(.top, 6)
            }
            Text("- \(note.mine ? "You" : note.by)" + (note.edited ? "  ·  edited" : ""))
                .font(.system(size: 11)).foregroundStyle(.black)
                .padding(.top, 22)
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 14)
        .frame(maxWidth: .infinity, minHeight: 81, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) { Circle().fill(dot).frame(width: 24, height: 24).padding(.trailing, 16).padding(.bottom, 12) }
        .notePaper()
    }
}
