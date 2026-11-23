import SwiftUI

/// BRD-01 Board / today
struct BoardView: View {
    @Environment(BoardStore.self) private var store
    @Environment(TipsStore.self) private var tips
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deleteTitle = "Delete this?"      // kept while the dialog fades out
    @State private var editingInto = false

    var body: some View {
        BoardScroller(startsOpen: tips.step == .into,
                      onIntoTap: { withAnimation(.snappy(duration: 0.25)) { editingInto = true } },
                      onAnswerTap: promptChipTapped)
        .overlay {
            if editingInto {
                IntoEditor {
                    withAnimation(.snappy(duration: 0.3)) { editingInto = false }
                    if !store.currentlyInto.isEmpty { tips.finishInto() }
                }
                    .transition(.opacity)
            }
        }
        .toolbarVisibility(editingInto || store.openedPostID != nil || store.openedJournalID != nil ? .hidden : .automatic, for: .tabBar)
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
        // tap a folded note: it opens as a full page over the blurred board
        .overlay {
            if let id = store.openedJournalID, let post = store.post(id) { JournalPage(post: post) }
        }
        .animation(.snappy(duration: 0.3), value: store.openedJournalID)
        // long-press > Edit
        .sheet(isPresented: flag(\.editRequest)) {
            if let id = store.editRequest, let post = store.post(id), let day = store.dayID(of: id) {
                PostComposerView(todayID: store.todayID, editing: (post, day))
            }
        }
        .onChange(of: store.deleteRequest) { _, id in
            if let id, let post = store.post(id) { deleteTitle = title(forDeleting: post) }
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

// MARK: - Scrolling board

/// The Prompts masthead is the top of the board's own scrolling content, so opening and closing it is just
/// scrolling: nothing resizes and nothing re-anchors while you drag, which is what keeps it smooth.
/// Today sits at the bottom. The board opens there with the masthead scrolled away, and scrolling up past
/// the oldest day brings the masthead into view. Let go halfway and it settles open or closed.
private struct BoardScroller: View {
    @Environment(BoardStore.self) private var store
    @Environment(TipsStore.self) private var tips
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let startsOpen: Bool
    let onIntoTap: () -> Void
    let onAnswerTap: () -> Void

    init(startsOpen: Bool, onIntoTap: @escaping () -> Void, onAnswerTap: @escaping () -> Void) {
        self.startsOpen = startsOpen
        self.onIntoTap = onIntoTap
        self.onAnswerTap = onAnswerTap
        _position = State(initialValue: ScrollPosition(edge: startsOpen ? .top : .bottom))
    }

    /// How far the board has scrolled: 0 = masthead fully open, `Mast.range` = tucked up under the title bar.
    @State private var offset: CGFloat = 0
    @State private var viewport: CGFloat = 874
    /// The status-bar inset the scroll view sits under. A nearly empty board is only just taller than the screen, so
    /// the page has to be this much taller for the masthead to be able to tuck fully away.
    @State private var topInset: CGFloat = 0
    @State private var position: ScrollPosition

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Masthead(onIntoTap: onIntoTap, onAnswerTap: onAnswerTap)
                        MastGap()
                        sheet
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .scrollPosition($position)
                .defaultScrollAnchor(startsOpen ? .top : .bottom)
                .scrollTargetBehavior(MastheadSnap(range: Mast.range))
                .ignoresSafeArea(edges: .top)
                .onScrollGeometryChange(for: CGFloat.self) { g in
                    g.contentOffset.y + g.contentInsets.top
                } action: { _, y in
                    offset = y
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
                // the tips: "into" starts with the masthead already open (a jump, not a scroll, so a new person never
                // sees the page move); the first post scrolls back down to the composer
                .onChange(of: tips.step, initial: true) { _, step in
                    if step == .into {
                        position.scrollTo(y: 0)
                    } else if step == .post {
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            withAnimation(.smooth(duration: 0.55)) { position.scrollTo(edge: .bottom) }
                        }
                    }
                }
                .onChange(of: store.postCount) {
                    tips.postMade()
                    // Show the day the post landed on, just under the title bar.
                    guard let day = store.lastPostedDayID else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))   // let the composer sheet finish dismissing
                        withAnimation(.smooth(duration: 0.55)) { proxy.scrollTo("day-\(day)", anchor: UnitPoint(x: 0.5, y: 0.2)) }
                    }
                }
                .onChange(of: store.highlightRequest) { _, id in
                    guard let id else { return }
                    store.highlightRequest = nil
                    if let day = store.dayID(of: id) { withAnimation(.smooth) { store.openDay(day) } }
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))     // let a closing composer get out of the way
                        withAnimation(.smooth(duration: 0.6)) { proxy.scrollTo(id, anchor: .center) }
                        try? await Task.sleep(for: .milliseconds(650))
                        store.highlightedPostID = id
                    }
                }
            }

            TitleBar(offset: offset) {
                withAnimation(.smooth(duration: 0.5)) {
                    position.scrollTo(y: offset < Mast.range / 2 ? Mast.range : 0)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.days) { day in
                DayRow(day: day, isLast: day.id == store.days.last?.id)
                    .id("day-\(day.id)")
            }
            // (the placeholder stays out of the way while the first-minutes tips are showing)
            if store.days.allSatisfy({ $0.posts.isEmpty }) && tips.step == .none {
                NewMonthEmptyState().padding(.top, 20)
            }
            // "Whats on your mind..." closes the board: always right under the last day, never stranded at the foot of a short page
            Color.clear.frame(height: 28)
            ComposerBubble { store.isComposing = true }
                .overlay(alignment: .topTrailing) {
                    if tips.step == .post {
                        // hangs under the bubble, so it moves with it wherever the bubble ends up
                        TipBubble(title: "Start with anything.",
                                  message: "A thought, a photo, what you ate. It lands on today, no setup.",
                                  arrow: .up(x: 237), width: 330)
                            .offset(y: 51.4 + 20)
                            .transition(TipBubble<EmptyView>.appear(from: UnitPoint(x: 0.72, y: 0), reduceMotion: reduceMotion))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 24)
                .padding(.bottom, 100)     // just enough to clear the tab bar
        }
        .frame(maxWidth: .infinity, minHeight: max(0, viewport - Mast.sheetTop) + topInset, alignment: .topLeading)
        .background(alignment: .top) {
            // black only shows in the two corners
            ZStack(alignment: .top) {
                Color.black.frame(height: Mast.corner)
                UnevenRoundedRectangle(topLeadingRadius: Mast.corner, topTrailingRadius: Mast.corner, style: .continuous)
                    .fill(Color("Paper"))
            }
        }
    }
}

/// Sizes taken from BRD-01 and BRD-02.
private enum Mast {
    static let barHeight: CGFloat = 121       // collapsed: title bar
    static let openHeight: CGFloat = 338      // expanded: title bar plus the chat
    static let stripHeight: CGFloat = 100     // the title strip while the card scrolls (clear of the first bubble)
    static let gap: CGFloat = 9
    static let corner: CGFloat = 24
    static var range: CGFloat { openHeight - barHeight }
    /// Where the board's top edge sits on screen when the masthead is tucked away.
    static var sheetTop: CGFloat { barHeight + gap }
}

/// Settles a scroll that ends halfway through the masthead: open or closed, by the direction of the flick.
struct MastheadSnap: ScrollTargetBehavior {
    let range: CGFloat
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let y = target.rect.minY
        guard y > 0, y < range else { return }
        let v = context.velocity.dy
        let close = abs(v) > 0.25 ? v > 0 : y > range / 2
        target.rect.origin.y = close ? range : 0
    }
}

/// The white card at the top of the board: you ask, the app answers, like a chat. It is part of the scrolled content.
private struct Masthead: View {
    @Environment(BoardStore.self) private var store
    @Environment(TipsStore.self) private var tips
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onIntoTap: () -> Void
    let onAnswerTap: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // behind the card's rounded bottom corners
            VStack(spacing: 0) { Spacer(); Color.black.frame(height: Mast.corner) }

            UnevenRoundedRectangle(bottomLeadingRadius: Mast.corner, bottomTrailingRadius: Mast.corner, style: .continuous)
                .fill(Color("Paper"))

            VStack(alignment: .leading, spacing: 0) {
                question("Currently into:", width: 151)
                Group {
                    if store.currentlyInto.trimmingCharacters(in: .whitespaces).isEmpty {
                        EmptyIntoBubble(action: onIntoTap)
                    } else {
                        answer(store.currentlyInto, action: onIntoTap)
                    }
                }
                .padding(.top, -24)
                .padding(.leading, 163)
                question("This month: \(store.prompt)", width: 267).padding(.top, 14)
                replyRow.padding(.top, 14)
            }
            .padding(.leading, 16).padding(.trailing, 27)
            .padding(.top, 110)

            if tips.step == .into {
                TipBubble(title: "What are you into right now?",
                          message: "Tap to set it. It sits up here like a status, and you can change it whenever.",
                          arrow: .up(x: 285), width: 346) {
                    TipGhostButton(title: "Not now") { tips.finishInto() }
                }
                .padding(.leading, 28).padding(.top, 186)
                .transition(TipBubble<EmptyView>.appear(from: .topTrailing, reduceMotion: reduceMotion))
            }
        }
        .frame(height: Mast.openHeight)
    }

    private func question(_ text: String, width: CGFloat) -> some View { ChatQuestion(text: text, width: width) }

    private func answer(_ text: String, action: @escaping () -> Void) -> some View { ChatAnswer(text: text, action: action) }

    @ViewBuilder private var replyRow: some View {
        let post = store.promptAnswerID.flatMap { store.post($0) }
        HStack {
            Spacer(minLength: 0)
            if let post {
                ChatAnswer(post: post, action: onAnswerTap)
            } else {
                AddAnswerBubble(action: onAnswerTap)
            }
        }
    }
}

/// The app's side of the chat: white, left.
struct ChatQuestion: View {
    let text: String
    let width: CGFloat
    var body: some View {
        Text(text)
            .font(Typo.pixel(12))
            .foregroundStyle(.black)
            .lineLimit(2)        // a long question wraps to a second line inside the same pill
            .multilineTextAlignment(.leading)
            .padding(.leading, 18).padding(.trailing, 14)
            .frame(width: width, height: 48, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Your side of the chat: faint gray, right.
struct ChatAnswer: View {
    let text: String
    /// A picture answer shows the photo in the bubble, with its caption beside it.
    var image: UIImage? = nil
    let action: () -> Void

    init(text: String, image: UIImage? = nil, action: @escaping () -> Void) {
        self.text = text; self.image = image; self.action = action
    }

    /// An answer made of a post: a photo brings its picture along.
    init(post: Post, action: @escaping () -> Void) {
        self.init(text: PromptChat.summary(of: post), image: post.image?.uiImage, action: action)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                if let image {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 46, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                        .rotationEffect(.degrees(-3))
                }
                Text(text)
                    .font(Typo.pixel(12))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(image == nil ? nil : 3)
            }
                .padding(image == nil ? 12 : 10)
                .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.black.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .frame(maxWidth: 196, alignment: .trailing)          // wraps at 196, but a short answer hugs its words
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// The dashed "Add an answer..." bubble. The first time the card comes into view with nothing answered, the bubble
/// grows a little with a springy wobble, the dashes march around it for a few seconds and the outline firms up, then
/// it settles back. Once per launch: a hello, not a nag.
private struct AddAnswerBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let action: () -> Void

    @MainActor private static var played = false

    @State private var phase: CGFloat = 0
    @State private var firm = false
    @State private var grown = false

    var body: some View {
        Button(action: action) {
            Text("Add an answer...")
                .font(Typo.pixel(12))
                .foregroundStyle(.black.opacity(firm ? 0.55 : 0.2))
                .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 10)
                .frame(width: 151, alignment: .leading)
                .background(.black.opacity(firm ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.black.opacity(firm ? 0.55 : 0.15),
                                  style: StrokeStyle(lineWidth: firm ? 1.4 : 1, dash: [4, 3], dashPhase: phase)))
        }
        .buttonStyle(PressableStyle())
        .scaleEffect(grown ? 1.1 : 1, anchor: .trailing)
        .rotationEffect(.degrees(grown ? -1.5 : 0), anchor: .trailing)
        .accessibilityLabel("Answer the prompt")
        .onScrollVisibilityChange(threshold: 0.7) { visible in
            guard visible, !reduceMotion, !Self.played else { return }
            Self.played = true
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(.spring(duration: 0.55, bounce: 0.55)) { grown = true }
                withAnimation(.easeOut(duration: 0.3)) { firm = true }
                withAnimation(.linear(duration: 3.2)) { phase = -49 }        // the ants march, once
                try? await Task.sleep(for: .milliseconds(3200))
                withAnimation(.spring(duration: 0.7, bounce: 0.4)) { grown = false }
                withAnimation(.easeInOut(duration: 0.6)) { firm = false }
                phase = 0
            }
        }
    }
}

/// The 9pt between the card and the board: solid black, as in the design.
private struct MastGap: View {
    var body: some View { Color.black.frame(height: Mast.gap) }
}

/// The area just outside two rounded top corners: what shows black beside a rounded sheet.
struct OutsideTopCorners: Shape {
    let radius: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path(r)
        p.addPath(UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: .continuous)
            .path(in: CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height + radius)))
        return p
    }
}

/// The fixed title bar: "Prompts" and the month. Once the card has scrolled up out of view it stays as the white bar
/// (its own bottom edge squares off while the card is opening, so the two read as one).
private struct TitleBar: View {
    @Environment(BoardStore.self) private var store
    let offset: CGFloat
    let onTap: () -> Void

    /// 0 = open, 1 = closed
    private var f: CGFloat { min(1, max(0, offset / Mast.range)) }
    private var tucked: Bool { offset >= Mast.range - 1 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // While the card is on its way up, the bar is just a strip of the same paper behind the title, square at
            // the bottom with a soft fade, so nothing shows a hard edge or a second set of corners. Once the card is
            // tucked away it becomes the rounded title bar, in exactly the card's place.
            ZStack(alignment: .bottom) {
                if tucked { Color.black.frame(height: Mast.corner) }
                UnevenRoundedRectangle(bottomLeadingRadius: tucked ? Mast.corner : 0,
                                       bottomTrailingRadius: tucked ? Mast.corner : 0, style: .continuous)
                    .fill(Color("Paper"))
            }
            .frame(height: tucked ? Mast.barHeight : Mast.stripHeight)

            LinearGradient(colors: [Color("Paper"), Color("Paper").opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 26)
                .offset(y: Mast.stripHeight)
                .opacity(tucked ? 0 : 1)
                .allowsHitTesting(false)

            // A soft blur where the board slides up under the title. It sits under the black corners (drawn next), which
            // stay crisp.
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(height: 56)
                .offset(y: Mast.sheetTop)
                .opacity(tucked ? 1 : 0)
                .allowsHitTesting(false)

            // Under the bar the board always starts after a black gap with rounded top corners; the board
            // scrolls beneath this frame once the card is tucked away.
            VStack(spacing: 0) {
                Color.clear.frame(height: Mast.barHeight)
                Color.black.frame(height: Mast.gap)
                OutsideTopCorners(radius: Mast.corner).fill(.black, style: FillStyle(eoFill: true))
                    .frame(height: Mast.corner)
                    .clipped()      // the cut-out reaches below the corners; keep only the corners
            }
            .opacity(tucked ? 1 : 0)      // only once the card is tucked away
            .allowsHitTesting(false)

            Text("Prompts")
                .font(.system(size: 18 + 8 * (1 - f), weight: f > 0.5 ? .medium : .bold))
                .padding(.leading, 16 + 12 * f)
                .padding(.top, 57 + 12 * f)
            Text(store.monthName)
                .font(Typo.pixel(18))
                .foregroundStyle(.black.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 27)
                .padding(.top, 70)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Mast.barHeight, alignment: .top)
        .ignoresSafeArea(edges: .top)
        // only the title strip toggles the card; the bubbles under it (like "currently into") take their own taps
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: 100)
                .contentShape(.rect)
                .onTapGesture(perform: onTap)
                .ignoresSafeArea(edges: .top)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Prompts")
        .accessibilityHint(offset < Mast.range / 2 ? "Closes the prompts" : "Opens the prompts")
    }
}

private struct DayRow: View {
    @Environment(BoardStore.self) private var store
    let day: BoardDay
    let isLast: Bool

    private let gutter: CGFloat = 44
    private let dot: CGFloat = 8

    private var collapsed: Bool { store.collapsedDays.contains(day.id) }

    /// The date. With posts under it, tapping it folds the day away (and a second tap opens it again).
    @ViewBuilder private var dateLabel: some View {
        let label = HStack(spacing: 4) {
            if day.id == store.todayID {
                Text("today").font(Typo.pixel(14)).foregroundStyle(.black)
            }
            Text("\(store.monthShort) \(day.id)").font(Typo.pixel(14)).foregroundStyle(.black.opacity(0.5))
            if !day.posts.isEmpty {
                if collapsed {
                    Text("· \(day.posts.count) post\(day.posts.count == 1 ? "" : "s")")
                        .font(Typo.pixel(14)).foregroundStyle(.black.opacity(0.35))
                        .transition(.opacity)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black.opacity(0.35))
                    .rotationEffect(.degrees(collapsed ? -90 : 0))
                    .padding(.leading, 2)
            }
        }
        .frame(height: 17)

        if day.posts.isEmpty {
            label
        } else {
            label
                .padding(.trailing, 24)           // a little more to tap
                .contentShape(.rect)
                .onTapGesture { withAnimation(.smooth(duration: 0.4)) { store.toggleDay(day.id) } }
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: collapsed)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("\(store.monthShort) \(day.id), \(collapsed ? "folded" : "open")")
                .accessibilityHint(collapsed ? "Opens this day" : "Folds this day away")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateLabel

            if day.posts.isEmpty {
                Text("its kinda empty...")
                    .font(Typo.scaled(14, .regular, relativeTo: .subheadline).italic())
                    .foregroundStyle(.black.opacity(0.5))
                    .padding(.top, 5)
                    .transition(.opacity)
            } else if !collapsed {
                DayPosts(posts: day.posts)
                    .padding(.top, 9)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
            }
        }
        .padding(.leading, gutter)
        .padding(.bottom, isLast ? 0 : 41)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) { Dot(isToday: day.id == store.todayID).frame(width: dot, height: dot).offset(x: 25, y: 4.5) }
        .background(alignment: .topLeading) {
            if !isLast {
                // the timeline: from this dot's center down to the next day's dot
                Capsule()
                    .fill(.black.opacity(0.1))
                    .frame(width: 3)
                    .padding(.top, 8.5)
                    .padding(.bottom, -28.5)   // reaches the next dot, past its 20pt top cushion
                    .offset(x: 27.5)
            }
        }
        .animation(.smooth, value: day.posts.isEmpty)
        .animation(.smooth(duration: 0.4), value: collapsed)
        .padding(.top, 20)   // cushion above the label, so scrollTo(day, anchor: .top) isn't flush with the sheet edge
    }
}

struct Dot: View {
    var isToday = false
    var body: some View { Circle().fill(isToday ? Color(red: 0.992, green: 0.392, blue: 0.133) : Color(white: 0.592)) }
}
