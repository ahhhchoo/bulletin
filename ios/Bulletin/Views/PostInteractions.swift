import SwiftUI

// MARK: - A pinned post you can touch

/// Dragging only carries the post's id around; reordering is done by the store.
struct PostToken: Codable, Transferable {
    let id: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// One post on the board.
/// - Tap: opens it (sticky and photo as a card in place, folded notes as a full page).
/// - Long-press: lifts it with a haptic and offers Edit and Delete. Keep going and drag it to
///   reorder within its day, like moving apps on the home screen.
struct PostCell: View {
    @Environment(BoardStore.self) private var store
    @Environment(NotesStore.self) private var notes
    let post: Post

    @State private var frame: CGRect = .zero
    @State private var dropTargeted = false
    @State private var glow = 0.0               // the soft pulse after tapping the answered prompt card

    var body: some View {
        PostView(post: post)
            .overlay(alignment: .topTrailing) {
                // friends' notes live under the photo; the board only shows that there are some
                if case .photo = post.kind, notes.count(post.id) > 0 { NoteBadge(count: notes.count(post.id)).offset(x: 10, y: -10) }
            }
            .opacity(store.openedPostID == post.id ? 0 : 1)       // the opened card stands in for it
            .shadow(color: Color("DayPink").opacity(0.75 * glow), radius: 22)
            .scaleEffect((dropTargeted ? 1.05 : 1) + 0.04 * glow)
            .onChange(of: store.highlightedPostID) { _, id in
                guard id == post.id else { return }
                store.highlightedPostID = nil
                withAnimation(.easeOut(duration: 0.3)) { glow = 1 }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.easeOut(duration: 1.7)) { glow = 0 }       // soft, then it fades
                }
            }
            .animation(.spring(duration: 0.28, bounce: 0.35), value: dropTargeted)
            .contentShape(.rect)
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { frame = $0 }
            .onTapGesture(perform: open)
            .contextMenu { menu }
            .draggable(PostToken(id: post.id)) {
                PostView(post: post, animated: false).scaleEffect(1.06)
            }
            .dropDestination(for: PostToken.self) { tokens, _ in
                guard let dragged = tokens.first else { return false }
                return withAnimation(.spring(duration: 0.42, bounce: 0.2)) { store.reorder(dragged.id, onto: post.id) }
            } isTargeted: { dropTargeted = $0 }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Edit") { edit() }
            .accessibilityAction(named: "Delete") { store.deleteRequest = post.id }
    }

    @ViewBuilder private var menu: some View {
        Button(editTitle, systemImage: "pencil", action: edit)
        Button("Delete", systemImage: "trash", role: .destructive) { store.deleteRequest = post.id }
    }

    private var editTitle: String {
        if case .photo = post.kind { return "Edit caption" }
        return "Edit"
    }

    private func edit() {
        store.editRequest = post.id
    }

    private func open() {
        if case .journal = post.kind {
            store.openedJournalID = post.id
        } else {
            store.openedFrame = frame
            store.openedPostID = post.id
        }
    }
}

// MARK: - Opened card, in place

/// A sticky or photo opened where it sits on your own board.
struct OpenedPostOverlay: View {
    @Environment(BoardStore.self) private var store
    let post: Post

    var body: some View {
        PostDetailView(post: post,
                       origin: store.openedFrame,
                       dayLabel: store.dayID(of: post.id).map(store.fullLabel),
                       owner: true,
                       friendName: "") { store.openedPostID = nil }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: store.openedPostID)
    }
}

/// The detailed view: the post straightens up and grows, and the board dims behind it. Tap outside or pull it down
/// to put it back.
///
/// A photo can have notes from friends under it. They are not on the board and not on this screen: a drawer docked
/// at the bottom opens a layer under the picture (see `NotesLayers`).
struct PostDetailView: View {
    let post: Post
    /// Where it was on screen, so it grows from there. Nil: it grows from the middle (a friend's photo).
    let origin: CGRect?
    let dayLabel: String?
    /// Your own post (read, reply, tuck away) or a friend's (leave a note).
    let owner: Bool
    let friendName: String
    let onClose: () -> Void

    @State private var expanded = false
    @State private var notesOpen = false
    @State private var cardSize = CGSize(width: 156, height: 150)
    @State private var pull: CGFloat = 0

    private var isPhoto: Bool { if case .photo = post.kind { true } else { false } }

    var body: some View {
        GeometryReader { geo in
            let start = origin.map { CGPoint(x: $0.midX, y: $0.midY) } ?? CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.4)
            let target = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.40 + pull)
            // Photos open bigger than notes: they are the thing you want a good look at.
            // Wide photos are short, so they can open nearly edge to edge without crowding the screen.
            let isLandscape = (post.image?.aspect ?? 1) > 1.1
            let scale = min(isPhoto ? (isLandscape ? 2.4 : 1.9) : 1.55,
                            (geo.size.width - (isLandscape ? 36 : 48)) / max(cardSize.width, 1),
                            geo.size.height * 0.6 / max(cardSize.height, 1))
            // With the notes layer open the photo shrinks back to about its pinned size, up at the top.
            let small = min(scale, 1.0)
            let smallTarget = CGPoint(x: geo.size.width / 2, y: 64 + cardSize.height * small / 2)
            let shownScale = notesOpen ? small : scale
            let shownTarget = notesOpen ? smallTarget : target
            // The caption is 14pt on screen whatever the zoom, so a long one runs below the card; keep the date clear of it.
            let captionHang: CGFloat = {
                guard case .photo(let c) = post.kind, !c.isEmpty else { return 0 }
                let size = 14 / shownScale
                let perLine = max(1, Int((PhotoMetrics.pinWidth - 26) / (size * 0.6)))
                let lines = (c.count + perLine - 1) / perLine
                return max(0, CGFloat(lines) * size * 1.3 + 20 - 43)
            }()
            let layerTop = smallTarget.y + cardSize.height * small / 2 + 30 + captionHang * small

            ZStack {
                Color.black.opacity(expanded ? 0.3 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { if notesOpen { notesOpen = false } else { close() } }

                PostView(post: post, animated: false, tilt: expanded ? 0 : 1, fullCaption: true,
                         captionSize: 14 / shownScale, captionVisible: expanded)
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self, of: \.size) { cardSize = $0 }
                    .scaleEffect(expanded ? shownScale : 1)
                    .shadow(color: .black.opacity(expanded ? 0.22 : 0), radius: 18, y: 10)
                    .position(expanded ? shownTarget : start)
                    .gesture(
                        DragGesture()
                            .onChanged { if !notesOpen { pull = max(0, $0.translation.height) } }
                            .onEnded { value in
                                if notesOpen { return }
                                if value.translation.height > 90 { close() }
                                else { withAnimation(.spring(duration: 0.35, bounce: 0.3)) { pull = 0 } }
                            }
                    )

                details
                    .position(x: geo.size.width / 2,
                              y: target.y + cardSize.height * scale / 2 + 34 + captionHang * scale)
                    .opacity(expanded && !notesOpen ? 1 : 0)
                    .animation(.easeOut(duration: 0.25).delay(expanded ? 0.2 : 0), value: expanded)
                    .animation(.easeOut(duration: 0.15), value: notesOpen)

                if isPhoto && expanded {
                    NotesLayers(post: post, owner: owner, friendName: friendName, open: $notesOpen, layerTop: layerTop)
                        .transition(.opacity)
                }
            }
            .animation(.spring(duration: 0.45, bounce: 0.12), value: notesOpen)
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.2)) { expanded = true } }
    }

    /// Which day it belongs to, and when it was added if it was clipped on later.
    @ViewBuilder private var details: some View {
        if dayLabel != nil || (post.isClipped && post.addedLabel != nil) { detailsPill }
    }

    private var detailsPill: some View {
        VStack(spacing: 4) {
            if let dayLabel {
                Text(dayLabel).font(.system(size: 15, weight: .medium))
            }
            if post.isClipped, let added = post.addedLabel {
                Label("Added \(added)", systemImage: "paperclip")
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.55))
            }
        }
        .foregroundStyle(.black.opacity(0.8))
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())     // stays readable over the dimmed board
    }

    private func close() {
        withAnimation(.spring(duration: 0.42, bounce: 0.12)) { expanded = false; pull = 0 }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            onClose()
        }
    }
}

// MARK: - Folded note, opened

/// Folded notes open into a full page for reading. (BRD-06 isn't designed yet, so this is a plain
/// serif page for now.)
struct JournalPage: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let post: Post

    private var title: String { if case .journal(let t, _) = post.kind { t } else { "" } }
    private var text: String { if case .journal(_, let b) = post.kind { b } else { "" } }
    private var readMinutes: Int { max(1, text.split(separator: " ").count / 200) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let day = store.dayID(of: post.id) {
                        Text(store.fullLabel(day))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black.opacity(0.5))
                    }
                    if !title.isEmpty {
                        Text(title)
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                    }
                    Text(text)
                        .font(.system(size: 19, design: .serif))
                        .lineSpacing(7)
                    Text("\(readMinutes) min read")
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.45))
                }
                .foregroundStyle(.black)
                .padding(26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 2))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color("Paper"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.foregroundStyle(.black) }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color("Paper"))
        .tint(.black)
    }
}
