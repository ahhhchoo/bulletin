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
    let post: Post

    @State private var frame: CGRect = .zero
    @State private var dropTargeted = false

    var body: some View {
        PostView(post: post)
            .opacity(store.openedPostID == post.id ? 0 : 1)       // the opened card stands in for it
            .scaleEffect(dropTargeted ? 1.05 : 1)
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
        if case .photo = post.kind { store.captionRequest = post.id } else { store.editRequest = post.id }
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

/// A sticky or photo opened where it sits: it straightens up, grows, and the board dims behind it.
/// Tap outside or pull it down to put it back.
struct OpenedPostOverlay: View {
    @Environment(BoardStore.self) private var store
    let post: Post

    @State private var expanded = false
    @State private var cardSize = CGSize(width: 156, height: 150)
    @State private var pull: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let origin = CGPoint(x: store.openedFrame.midX, y: store.openedFrame.midY)
            let target = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.40 + pull)
            let scale = min(1.55, (geo.size.width - 64) / max(cardSize.width, 1))

            ZStack {
                Color.black.opacity(expanded ? 0.3 : 0)
                    .ignoresSafeArea()
                    .onTapGesture(perform: close)

                PostView(post: post, animated: false, tilt: expanded ? 0 : 1)
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self, of: \.size) { cardSize = $0 }
                    .scaleEffect(expanded ? scale : 1)
                    .shadow(color: .black.opacity(expanded ? 0.22 : 0), radius: 18, y: 10)
                    .position(expanded ? target : origin)
                    .gesture(
                        DragGesture()
                            .onChanged { pull = max(0, $0.translation.height) }
                            .onEnded { value in
                                if value.translation.height > 90 { close() }
                                else { withAnimation(.spring(duration: 0.35, bounce: 0.3)) { pull = 0 } }
                            }
                    )

                details
                    .position(x: geo.size.width / 2,
                              y: target.y + cardSize.height * scale / 2 + 34)
                    .opacity(expanded ? 1 : 0)
                    .animation(.easeOut(duration: 0.25).delay(expanded ? 0.2 : 0), value: expanded)
            }
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.2)) { expanded = true } }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: store.openedPostID)
    }

    /// Which day it belongs to, and when it was added if it was clipped on later.
    private var details: some View {
        VStack(spacing: 4) {
            if let day = store.dayID(of: post.id) {
                Text(store.fullLabel(day))
                    .font(.system(size: 15, weight: .medium))
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
            store.openedPostID = nil
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
