import SwiftUI

private let layerPaper = Color(red: 0.925, green: 0.914, blue: 0.882)         // the deeper layer's paper
private let noteGreen = Color(red: 0.68, green: 0.88, blue: 0.81)
private let mineGreen = Color(red: 0.75, green: 0.91, blue: 0.85)
private let replyBlue = Color(red: 0.84, green: 0.90, blue: 0.97)

/// "There are notes under this photo": the same little count as a stack's, "+4" on a black capsule.
struct NoteBadge: View {
    let count: Int

    var body: some View {
        CountBadge(count: count)
            .accessibilityLabel("\(count) note\(count == 1 ? "" : "s") under this photo")
    }
}

/// A friend's note as a sticky, with the owner's reply (if any) tucked under it.
private struct NoteSticky: View {
    let note: PostNote
    let index: Int
    let owner: Bool
    let onReply: () -> Void
    let onTuck: () -> Void
    let onTakeBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: -6) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.text).font(Typo.pixel(13)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    Text(note.mine ? "you" : "from \(note.by)").foregroundStyle(.black.opacity(0.5))
                    Spacer(minLength: 0)
                    if owner {
                        if note.reply == nil { Button("Reply", action: onReply) }
                        Button("Tuck away", action: onTuck)
                    } else if note.mine {
                        Button("Take back", action: onTakeBack)
                    }
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.black.opacity(0.55))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 10)
            .frame(width: 272)
            .background(note.mine ? mineGreen : noteGreen, in: RoundedRectangle(cornerRadius: 2))
            .shadow(color: .black.opacity(0.14), radius: 2, y: 2)
            .overlay(alignment: .top) { Pushpin().offset(y: -4) }
            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1.2 : 1.3))
            .zIndex(1)

            if let reply = note.reply {
                VStack(alignment: .leading, spacing: 6) {
                    Text(reply).font(Typo.pixel(12.5)).foregroundStyle(.black)
                    Text("reply").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.black.opacity(0.5))
                }
                .padding(.horizontal, 11).padding(.top, 14).padding(.bottom, 8)
                .frame(width: 230, alignment: .leading)
                .background(replyBlue, in: RoundedRectangle(cornerRadius: 2))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
                .rotationEffect(.degrees(1))
                .offset(x: index.isMultiple(of: 2) ? 26 : 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: index.isMultiple(of: 2) ? .leading : .trailing)
    }
}

/// The drawer docked at the bottom of an opened photo, and the layer it opens into: the notes under the picture.
///
/// - Your own photo: you read the notes, reply to them or tuck them away. Nothing here asks you to add any.
/// - A friend's photo: a sticky waits at the bottom of the layer. Drag it up to leave a note.
struct NotesLayers: View {
    @Environment(NotesStore.self) private var store
    let post: Post
    let owner: Bool
    let friendName: String
    @Binding var open: Bool
    /// Where the layer's top edge sits once it is open, measured from the top of the screen.
    let layerTop: CGFloat

    private enum Writing: Identifiable, Equatable {
        case note
        case reply(PostNote.ID)
        var id: String { switch self { case .note: "note"; case .reply(let i): i.uuidString } }
    }
    @State private var writing: Writing?
    @State private var dragPoint: CGPoint?

    private var notes: [PostNote] { store.notes(post.id) }
    private var showsDrawer: Bool { owner ? !notes.isEmpty : true }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if showsDrawer {
                    drawer
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                        .opacity(open ? 0 : 1)
                        .allowsHitTesting(!open)
                        .animation(.easeOut(duration: 0.2), value: open)
                }
                layer(height: max(200, geo.size.height - layerTop))
                    .frame(width: geo.size.width)
                    .offset(y: open ? layerTop : geo.size.height + 60)
                    .allowsHitTesting(open)
                if let p = dragPoint {
                    RoundedRectangle(cornerRadius: 2).fill(mineGreen)
                        .frame(width: 118, height: 92)
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 10)
                        .rotationEffect(.degrees(-4)).scaleEffect(1.05)
                        .position(p).allowsHitTesting(false)
                }
                if let w = writing {
                    NoteWriter(
                        title: { if case .reply(let id) = w, let n = notes.first(where: { $0.id == id }) { "Reply to \(n.by)" } else { "To \(friendName), about this photo" } }(),
                        isReply: { if case .reply = w { true } else { false } }(),
                        onCancel: { withAnimation(.snappy) { writing = nil } },
                        onSend: { text in
                            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                                switch w {
                                case .note: store.addMine(text, to: post.id)
                                case .reply(let id): store.reply(text, to: id, on: post.id)
                                }
                                writing = nil
                            }
                        })
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.opacity)
                }
            }
            .coordinateSpace(name: "layers")
            .animation(.spring(duration: 0.45, bounce: 0.12), value: open)
        }
    }

    // MARK: the drawer

    private var drawer: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<3, id: \.self) { i in
                Rectangle().fill([Color(red: 0.62, green: 0.84, blue: 0.76), Color(red: 0.71, green: 0.89, blue: 0.83), noteGreen][i])
                    .frame(width: 118, height: 92)
                    .rotationEffect(.degrees([-7, 6, 0][i]))
                    .offset(x: [-18, 16, 0][i], y: -56)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: -1)
            }
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                .fill(layerPaper)
                .frame(height: 118)
                .shadow(color: .black.opacity(0.22), radius: 12, y: -4)
                .overlay(alignment: .top) {
                    VStack(spacing: 14) {
                        Capsule().fill(.black.opacity(0.2)).frame(width: 38, height: 5)
                        Text(owner ? "\(notes.count) note\(notes.count == 1 ? "" : "s")" : "Add a note")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.black.opacity(0.6))
                    }
                    .padding(.top, 10)
                }
        }
        .frame(height: 118, alignment: .bottom)
        .contentShape(.rect)
        .onTapGesture { open = true }
        .gesture(DragGesture(minimumDistance: 16).onEnded { if $0.translation.height < -30 { open = true } })
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(owner ? "\(notes.count) notes under this photo" : "Add a note")
    }

    // MARK: the layer

    private func layer(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Capsule().fill(.black.opacity(0.2)).frame(width: 38, height: 5)
                Text("\(owner ? "Notes from friends" : "Notes on this photo") · \(notes.count)")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.black.opacity(0.55))
            }
            .padding(.top, 8).padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .onTapGesture { open = false }
            .gesture(DragGesture(minimumDistance: 16).onEnded { if $0.translation.height > 30 { open = false } })

            ScrollView {
                VStack(spacing: 16) {
                    if notes.isEmpty {
                        Text(owner ? "No notes yet." : "No notes yet.\nDrag the sticky up to leave the first one.")
                            .font(.callout).multilineTextAlignment(.center).foregroundStyle(.black.opacity(0.45))
                            .padding(.top, 50)
                    }
                    ForEach(Array(notes.enumerated()), id: \.element.id) { i, n in
                        NoteSticky(note: n, index: i, owner: owner,
                                   onReply: { writing = .reply(n.id) },
                                   onTuck: { withAnimation(.snappy) { store.tuck(n.id, on: post.id) } },
                                   onTakeBack: { withAnimation(.snappy) { store.takeBack(on: post.id) } })
                    }
                }
                .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, owner ? 60 : 170)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: height, alignment: .top)
        .background(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
            .fill(layerPaper).shadow(color: .black.opacity(0.22), radius: 14, y: -6).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .bottom) { if !owner { dock } }
    }

    /// A sticky at the bottom of a friend's photo layer. Drag it up into the layer to write a note.
    private var dock: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(noteGreen)
                .frame(width: 52, height: 52)
                .overlay(Image(systemName: "plus").font(.system(size: 26, weight: .medium)).foregroundStyle(.black.opacity(0.35)))
                .shadow(color: .black.opacity(0.14), radius: 2, y: 2)
                .rotationEffect(.degrees(8))
                .opacity(dragPoint == nil ? 1 : 0.35)
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .named("layers"))
                        .onChanged { dragPoint = $0.location }
                        .onEnded { v in
                            let dropped = v.location.y > layerTop + 30
                            withAnimation(.snappy) { dragPoint = nil }
                            if dropped { withAnimation(.snappy) { writing = .note } }
                        })
                .onTapGesture { withAnimation(.snappy) { writing = .note } }
                .accessibilityLabel("Sticky note")
                .accessibilityHint("Drag up into the notes, or tap, to write a note")
            Text("Drag a sticky up to add a note").font(.footnote).foregroundStyle(.black.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40).padding(.bottom, 26)
        .background(LinearGradient(colors: [layerPaper.opacity(0), layerPaper, layerPaper], startPoint: .top, endPoint: .bottom))
    }
}

/// Where you write a note or a reply, over a dimmed screen.
struct NoteWriter: View {
    let title: String
    let isReply: Bool
    let onCancel: () -> Void
    let onSend: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    private let limit = 140

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.32).ignoresSafeArea().onTapGesture { focused = false }
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.black.opacity(0.5))
                    TextField(isReply ? "Write a reply…" : "Write something…", text: $text, axis: .vertical)
                        .focused($focused)
                        .font(Typo.pixel(15))
                        .lineLimit(3...6)
                        .onChange(of: text) { _, new in if new.count > limit { text = String(new.prefix(limit)) } }
                }
                .padding(.horizontal, 14).padding(.top, 22).padding(.bottom, 14)
                .frame(width: 240, alignment: .topLeading)
                .frame(minHeight: 160, alignment: .topLeading)
                .background(isReply ? replyBlue : noteGreen, in: RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 4)
                .overlay(alignment: .top) { Pushpin().offset(y: -4) }
                .rotationEffect(.degrees(-2))
                HStack(spacing: 10) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18).padding(.vertical, 10).background(.white, in: Capsule())
                    Button(isReply ? "Reply" : "Stick it") { onSend(trimmed) }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 10).background(.black, in: Capsule())
                        .opacity(trimmed.isEmpty ? 0.3 : 1)
                        .disabled(trimmed.isEmpty)
                }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(PressableStyle())
            }
            .padding(.top, 90)
        }
        .onAppear { focused = true }
    }
}
