import SwiftUI

/// BRD-01 Board / today
struct BoardView: View {
    @Environment(BoardStore.self) private var store
    /// 0 = masthead fully open, 1 = squeezed down to the title bar. Driven by scrolling the board.
    @State private var squeeze: CGFloat = 0
    @State private var scrollToTop = 0
    @State private var captionDraft = ""
    @State private var deleteTitle = "Delete this?"      // kept while the dialog fades out
    @State private var editingInto = false

    var body: some View {
        ZStack(alignment: .top) {
            Color("Backdrop").ignoresSafeArea()

            // The board never changes size, so scrolling can't feed back into its own layout (that made the
            // masthead jitter on a fast scroll). The masthead is drawn over the board's top instead of pushing
            // it down, and the board masks its own rounded top edge to sit just below the masthead.
            VStack(spacing: 0) {
                Color.clear.frame(height: HeaderView.compactHeight + 8)
                BoardSheet(squeeze: $squeeze, scrollToTop: scrollToTop)
            }

            HeaderView(squeeze: squeeze, onChipTap: promptChipTapped, onIntoTap: { withAnimation(.snappy(duration: 0.25)) { editingInto = true } })
        }
        .overlay {
            if editingInto {
                IntoEditor { withAnimation(.snappy(duration: 0.3)) { editingInto = false } }
                    .transition(.opacity)
            }
        }
        .toolbarVisibility(editingInto ? .hidden : .automatic, for: .tabBar)
        .sheet(isPresented: composing, onDismiss: { store.answeringPrompt = false }) {
            PostComposerView(todayID: store.todayID)
        }
        .onChange(of: store.answeringPrompt) { _, answering in
            if answering { store.isComposing = true }
        }
        // tap a sticky or photo: it opens as a card in place
        .overlay {
            if let id = store.openedPostID, let post = store.post(id) {
                OpenedPostOverlay(post: post)
            }
        }
        // tap a folded note: it opens as a full page
        .sheet(isPresented: flag(\.openedJournalID)) {
            if let id = store.openedJournalID, let post = store.post(id) { JournalPage(post: post) }
        }
        // long-press > Edit
        .sheet(isPresented: flag(\.editRequest)) {
            if let id = store.editRequest, let post = store.post(id), let day = store.dayID(of: id) {
                PostComposerView(todayID: store.todayID, editing: (post, day))
            }
        }
        // long-press > Edit caption (photos)
        .alert("Edit caption", isPresented: flag(\.captionRequest)) {
            TextField("Caption", text: $captionDraft)
            Button("Save") {
                if let id = store.captionRequest { store.updateCaption(id, caption: captionDraft) }
                store.captionRequest = nil
            }
            Button("Cancel", role: .cancel) { store.captionRequest = nil }
        }
        .onChange(of: store.deleteRequest) { _, id in
            if let id, let post = store.post(id) { deleteTitle = title(forDeleting: post) }
        }
        .onChange(of: store.captionRequest) { _, id in
            if let id, case .photo(let caption)? = store.post(id)?.kind { captionDraft = caption }
        }
        // long-press > Delete: always confirmed, it can't be undone
        .confirmationDialog(deleteTitle, isPresented: flag(\.deleteRequest), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = store.deleteRequest { withAnimation(.spring(duration: 0.45, bounce: 0.1)) { store.delete(id) } }
                store.deleteRequest = nil
            }
            Button("Cancel", role: .cancel) { store.deleteRequest = nil }
        } message: {
            Text("This can’t be undone.")
        }
    }

    private var composing: Binding<Bool> {
        Binding(get: { store.isComposing }, set: { store.isComposing = $0 })
    }

    /// A Bool view of "is this request set", for sheets, alerts and dialogs. Clearing it clears the request.
    private func flag(_ path: ReferenceWritableKeyPath<BoardStore, Post.ID?>) -> Binding<Bool> {
        Binding(get: { store[keyPath: path] != nil }, set: { if !$0 { store[keyPath: path] = nil } })
    }

    private func title(forDeleting post: Post) -> String {
        switch post.kind {
        case .photo: "Delete this photo?"
        case .sticky: "Delete this note?"
        case .journal: "Delete this entry?"
        }
    }

    /// Unanswered: point the next post at the prompt. Answered: jump to the answer.
    private func promptChipTapped() {
        if let id = store.promptAnswerID { store.highlightRequest = id }
        else { store.answeringPrompt = true }
    }
}

// MARK: - Header

/// The masthead: month title, "currently into" and prompt cards. It squeezes to a title bar as the board
/// scrolls up, and opens back up as soon as you scroll back down the page.
private struct HeaderView: View {
    @Environment(BoardStore.self) private var store
    @State private var page: Int? = 0
    let squeeze: CGFloat                // 0...1
    let onChipTap: () -> Void
    let onIntoTap: () -> Void

    // content heights below the status bar (design: 214 and 101 in total with the 44pt status bar)
    static let fullHeight: CGFloat = 170
    static let compactHeight: CGFloat = 57
    static var range: CGFloat { fullHeight - compactHeight }

    private var fade: Double { Double(max(0, 1 - squeeze * 1.7)) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text("My November")
                .font(Typo.scaled(24, .medium, relativeTo: .title))
                .padding(.leading, 28)
                .offset(y: 15 - 9 * squeeze)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 5) {
                    HeaderCard(background: "CardInto", tag: 0) {
                        Button(action: onIntoTap) {
                            BigWord(label: "currently into", value: store.currentlyInto)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .contentShape(.rect)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityHint("Change what you are into")
                    }
                    HeaderCard(background: "CardPrompt", tag: 1) {
                        PromptChat(
                            question: store.prompt,
                            answer: store.promptAnswerID.flatMap { store.post($0) },
                            allowsAnswering: true,
                            onAnswer: onChipTap,
                            actions: [
                                ChatAction(title: "Show my answer", icon: "arrow.down.to.line", run: onChipTap),
                                ChatAction(title: "Remove answer", icon: "xmark", destructive: true) {
                                    withAnimation(.snappy) { store.removePromptAnswer() }
                                },
                            ])
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page)
            .contentMargins(.horizontal, 27, for: .scrollContent)
            .frame(height: 76)
            .scaleEffect(1 - 0.04 * squeeze)
            .offset(y: 59 - 14 * squeeze)
            .opacity(fade)
            .allowsHitTesting(fade > 0.2)

            PageDots(current: page ?? 0, count: 2)
                .frame(maxWidth: .infinity)
                .offset(y: 146)
                .opacity(fade)

            // when squeezed, the prompt stays reachable
            HStack {
                Spacer()
                PromptChip(answered: store.promptAnswerID != nil, action: onChipTap)
                    .padding(.trailing, 20)
            }
            .offset(y: 11)
            .opacity(Double(min(1, max(0, (squeeze - 0.55) * 2.2))))
            .allowsHitTesting(squeeze > 0.6)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Self.fullHeight - Self.range * squeeze, alignment: .top)
        .clipped()
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("Paper"))
                .ignoresSafeArea(edges: .top)
        }
    }
}

/// Small prompt status in the squeezed masthead: dashed when unanswered, filled once you have answered.
private struct PromptChip: View {
    let answered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                ZStack {
                    if answered {
                        Circle().fill(Color("Sticky"))
                            .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 1.5))
                    } else {
                        Circle().strokeBorder(.black.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
                    }
                }
                .frame(width: 12, height: 12)
                Text(answered ? "prompt answered" : "answer the prompt")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(.black)
            .padding(.leading, 9)
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .background(Color("CardPrompt"), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

private struct HeaderCard<Content: View>: View {
    let background: String
    let tag: Int
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(background), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .containerRelativeFrame(.horizontal) { length, _ in length - 54 }
            .id(tag)
    }
}

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

// MARK: - Board sheet

private struct BoardSheet: View {
    @Environment(BoardStore.self) private var store
    @Binding var squeeze: CGFloat
    let scrollToTop: Int

    /// While the board scrolls itself (to a new post's day), the masthead stays put.
    @State private var lockedUntil = Date.distantPast

    private struct Metrics: Equatable {
        var y: CGFloat
        var maxY: CGFloat
        var content: CGFloat
        var container: CGFloat
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id("board-top")
                    // newest day at the top, oldest at the bottom
                    ForEach(store.days.reversed()) { day in
                        DayRow(day: day, isLast: day.id == store.days.first?.id)
                            .id("day-\(day.id)")
                    }
                }
                // room for the open masthead, which sits over the top of the board
                .padding(.top, HeaderView.range)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, 110, for: .scrollContent)   // lets the last day scroll up above the tab bar
            .onScrollGeometryChange(for: Metrics.self) { g in
                Metrics(y: g.contentOffset.y + g.contentInsets.top,
                        // Where the board really ends. (Adding contentInsets.bottom here put "the end" past the
                        // real one, so the spring-back after a hard flick looked like scrolling up and
                        // reopened the masthead.)
                        maxY: max(0, g.contentSize.height - g.containerSize.height),
                        content: g.contentSize.height,
                        container: g.containerSize.height)
            } action: { old, new in
                // Ignore rubber-banding past either end so the masthead doesn't twitch.
                let y = min(max(new.y, 0), new.maxY)
                let oldY = min(max(old.y, 0), old.maxY)
                if y <= 0 { squeeze = 0; return }
                // A change in size moves the scroll offset by itself (the system clamps it); that is not the
                // user scrolling, so it must not open or close the masthead.
                guard new.content == old.content, new.container == old.container else { return }
                guard Date.now >= lockedUntil else { return }
                squeeze = min(1, max(0, squeeze + (y - oldY) / HeaderView.range))
            }
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
                    .fill(Color("Paper"))
                    .ignoresSafeArea(edges: .bottom)
            )
            // the board's visible top edge follows the bottom of the masthead
            .mask {
                VStack(spacing: 0) {
                    Color.clear.frame(height: HeaderView.range * (1 - squeeze))
                    UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .onChange(of: store.postCount) {
                // Show the day the post landed on, label at the top (works for clipped posts on past days too).
                guard let day = store.lastPostedDayID else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))   // let the composer sheet finish dismissing
                    lockedUntil = Date.now.addingTimeInterval(1)     // keep the masthead from reopening mid-scroll
                    withAnimation(.smooth(duration: 0.55)) {
                        squeeze = 1
                        proxy.scrollTo("day-\(day)", anchor: .top)
                    }
                }
            }
            .onChange(of: store.highlightRequest) { _, id in
                guard let id else { return }
                store.highlightRequest = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(450))     // let a closing composer get out of the way
                    lockedUntil = Date.now.addingTimeInterval(1.2)
                    withAnimation(.smooth(duration: 0.6)) { proxy.scrollTo(id, anchor: .center) }
                    try? await Task.sleep(for: .milliseconds(650))
                    store.highlightedPostID = id
                }
            }
            .onChange(of: scrollToTop) {
                withAnimation(.smooth(duration: 0.5)) { proxy.scrollTo("board-top", anchor: .top) }
            }
        }
    }
}

private struct DayRow: View {
    @Environment(BoardStore.self) private var store
    let day: BoardDay
    let isLast: Bool

    private let gutter: CGFloat = 44
    private let dot: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(store.shortLabel(day.id))
                .font(Typo.scaled(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.black.opacity(0.5))
                .frame(height: 17)

            // "Whats on your mind" sits in today's row, right under its label, instead of floating over the board
            if day.id == store.todayID {
                ComposerPill { store.isComposing = true }
                    .padding(.top, 14)
                    .padding(.leading, 8)
            }

            if day.posts.isEmpty {
                Text("its kinda empty...")
                    .font(Typo.scaled(14, .regular, relativeTo: .subheadline).italic())
                    .foregroundStyle(.black.opacity(0.5))
                    .padding(.top, day.id == store.todayID ? 16 : 5)   // clear of the button in today's row
                    .padding(.leading, day.id == store.todayID ? 8 : 0)
                    .transition(.opacity)
            } else {
                busyAwarePosts
                    .padding(.top, 18)
            }
        }
        .padding(.leading, gutter)
        .padding(.bottom, isLast ? 0 : 41)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) { Dot().frame(width: dot, height: dot).offset(x: 25, y: 4.5) }
        .background(alignment: .topLeading) {
            if !isLast {
                // the timeline: from this dot's center down to the next dot's center
                Rectangle()
                    .fill(.black.opacity(0.1))
                    .frame(width: 3)
                    .padding(.top, 8.5)
                    .padding(.bottom, -28.5)   // reaches the next dot, past its 20pt top cushion
                    .offset(x: 27.5)
            }
        }
        .animation(.smooth, value: day.posts.isEmpty)
        .padding(.top, 20)   // cushion above the label, so scrollTo(day, anchor: .top) isn't flush with the sheet edge
    }
}

extension DayRow {
    /// Folds the overflow of a busy day into a stack. Expanded days show everything plus a "Stack back up" pill.
    @ViewBuilder fileprivate var busyAwarePosts: some View {
        let keep = BoardStore.visibleIndices(in: day.posts)
        let stacked = day.posts.indices.filter { !keep.contains($0) }
        let isBusy = !stacked.isEmpty
        let expanded = store.expandedDays.contains(day.id)
        let folded = isBusy && !expanded

        DayPosts(
            posts: day.posts,
            shown: folded ? day.posts.indices.filter { keep.contains($0) } : Array(day.posts.indices),
            stackedCount: folded ? stacked.count : 0,
            stackPreview: folded ? stacked.first.map { day.posts[$0] } : nil,
            showPill: isBusy && expanded,
            onExpand: {
                withAnimation(.spring(duration: 0.6, bounce: 0.18)) { store.expand(day.id) }
            },
            onCollapse: {
                // Folding a day never moves the viewport.
                withAnimation(.spring(duration: 0.55, bounce: 0.12)) { store.collapse(day.id) }
            }
        )
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: expanded)
    }
}

private struct Dot: View {
    var body: some View { Circle().fill(.black) }
}
