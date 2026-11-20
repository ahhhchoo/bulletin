import SwiftUI

/// A friend's board: their look and their days. Nothing on it asks you to join in: to say something about a photo,
/// open it and scroll its notes (see `PhotoDetailView`).
struct FriendBoardView: View {
    @Environment(FriendsStore.self) private var store
    @Environment(NotesStore.self) private var notes
    @Environment(BoardStore.self) private var board
    let friend: Friend
    var nextLabel: String?
    var onNext: (() -> Void)?
    let onClose: () -> Void
    /// True while you are holding the board, looking at a photo or answering, so a queue waits for you.
    @Binding var busy: Bool
    /// How dark the strip above the board (the queue's progress bars) should be while something is open, to match the scrim.
    @Binding var topDim: Double

    @State private var openPost: Post?
    @State private var showAnswer = false
    @GestureState private var touching = false

    private var isBusy: Bool { openPost != nil || showAnswer || touching }
    private var days: [BoardDay] { store.boards[friend.id] ?? [] }

    // The same behavior as your own board: the prompt card is the top of the scrolling content, and scrolling down tucks
    // it away under a bar with the friend's name; scrolling up brings it back. Let go halfway and it settles open or closed.
    @State private var offset: CGFloat = 0
    @State private var viewport: CGFloat = 700
    @State private var cardHeight: CGFloat = 330
    @State private var position = ScrollPosition(edge: .top)

    private let barHeight: CGFloat = 48
    private let gap: CGFloat = 9
    private let corner: CGFloat = 24
    private var range: CGFloat { max(1, cardHeight - barHeight) }
    private var tucked: Bool { offset >= range - 1 }

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()      // paper, so a pull past the top or bottom never shows black; black is only the gap and the corners
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        card
                        Color.black.frame(height: gap)
                        sheet
                    }
                }
                .scrollIndicators(.hidden)
                .scrollPosition($position)
                .ignoresSafeArea(edges: .bottom)
                .mask { Rectangle().ignoresSafeArea(edges: .bottom) }      // the card scrolls under the bar, never up into the status bar
                .scrollTargetBehavior(MastheadSnap(range: range))
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in offset = y }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
                .simultaneousGesture(DragGesture(minimumDistance: 0).updating($touching) { _, s, _ in s = true })

                bar
            }
            if let post = openPost {
                PostDetailView(post: post, origin: nil,
                               dayLabel: days.first(where: { $0.posts.contains { $0.id == post.id } }).map { board.fullLabel($0.id) },
                               owner: false, friendName: friend.name) {
                    openPost = nil
                }
                .transition(.opacity)
            }
        }
        .onChange(of: isBusy) { _, v in busy = v }
        .onChange(of: openPost?.id) { _, id in
            var dim = 0.0
            if let post = openPost { if case .photo = post.kind { dim = 0.7 } else { dim = 0.5 } }
            withAnimation(.easeOut(duration: 0.3)) { topDim = dim }
        }
    }

    /// The prompt card: paper with rounded bottom corners over black. The header sits on top of it (see `bar`).
    private var card: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: corner, bottomTrailingRadius: corner, style: .continuous)
                .fill(Color("Paper"))
            VStack(spacing: 0) {
                Color.clear.frame(height: barHeight)
                cards.padding(.top, 14).padding(.bottom, 22)
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
    }

    /// The fixed top bar, like your own board's title bar: while the card scrolls it is a strip of paper behind the
    /// header; once the card is tucked away it is the rounded bar, in exactly the card's place.
    private var bar: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .bottom) {
                if tucked { Color.black.frame(height: corner) }
                UnevenRoundedRectangle(bottomLeadingRadius: tucked ? corner : 0, bottomTrailingRadius: tucked ? corner : 0, style: .continuous)
                    .fill(Color("Paper"))
            }
            .frame(height: barHeight)
            .contentShape(.rect)
            .onTapGesture { withAnimation(.smooth(duration: 0.5)) { position.scrollTo(y: offset < range / 2 ? range : 0) } }
            .accessibilityHidden(true)

            LinearGradient(colors: [Color("Paper"), Color("Paper").opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 22).offset(y: barHeight)
                .opacity(tucked ? 0 : 1).allowsHitTesting(false)

            Rectangle().fill(.ultraThinMaterial)
                .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(height: 56).offset(y: barHeight + gap)
                .opacity(tucked ? 1 : 0).allowsHitTesting(false)

            VStack(spacing: 0) {
                Color.clear.frame(height: barHeight)
                Color.black.frame(height: gap)
                OutsideTopCorners(radius: corner).fill(.black, style: FillStyle(eoFill: true))
                    .frame(height: corner).clipped()
            }
            .opacity(tucked ? 1 : 0).allowsHitTesting(false)

            header.frame(height: barHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: barHeight, alignment: .top)
    }

    // MARK: header and cards

    private var header: some View {
        HStack(spacing: 7) {
            Circle().fill(friend.color).frame(width: 28, height: 28)
            Text("\(friend.name)’s Bulletin").font(Typo.scaled(14, .medium, relativeTo: .subheadline))
            Spacer()
            if let nextLabel, let onNext {
                Button(action: onNext) {
                    Text(nextLabel).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7).background(.black, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 17, weight: .regular)).foregroundStyle(.black)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Close")
        }
        .padding(.leading, 25).padding(.trailing, 14).padding(.top, 8)
    }

    private var cards: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChatQuestion(text: "Currently into:", width: 151)
            ChatAnswer(text: friend.into, action: {}).allowsHitTesting(false)
                .padding(.top, -24).padding(.leading, 163)
            ChatQuestion(text: "This month: \(board.prompt)", width: 267).padding(.top, 14)
            HStack {
                Spacer(minLength: 0)
                if let answerPost {
                    ChatAnswer(post: answerPost, action: { showAnswer = true })
                        .popover(isPresented: $showAnswer, arrowEdge: .top) {
                            PostView(post: answerPost, animated: false, tilt: 0)
                                .padding(24)
                                .presentationCompactAdaptation(.popover)
                        }
                }
            }
            .padding(.top, 14)
        }
        .padding(.leading, 16).padding(.trailing, 27)
    }

    private var answerPost: Post? { days.flatMap(\.posts).first(where: \.isPromptAnswer) }

    // MARK: the board

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                DayBlock(day: day, isLast: i == days.count - 1) { post in
                    withAnimation(.snappy) { openPost = post }
                }
            }
        }
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity, minHeight: max(0, viewport - barHeight - gap), alignment: .topLeading)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Color.black.frame(height: corner)
                UnevenRoundedRectangle(topLeadingRadius: corner, topTrailingRadius: corner, style: .continuous).fill(Color("Paper"))
            }
        }
    }
}

private struct DayBlock: View {
    @Environment(BoardStore.self) private var board
    @Environment(NotesStore.self) private var notes
    let day: BoardDay
    let isLast: Bool
    let onOpen: (Post) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(board.shortLabel(day.id))
                .font(Typo.scaled(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.black.opacity(0.5)).frame(height: 17)
            if day.posts.isEmpty {
                Text("its kinda empty...")
                    .font(Typo.scaled(14, .regular, relativeTo: .subheadline).italic())
                    .foregroundStyle(.black.opacity(0.5)).padding(.top, 5)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(day.posts) { post in
                        PostView(post: post, animated: false)
                            .overlay(alignment: .topTrailing) {
                                if case .photo = post.kind, notes.count(post.id) > 0 {
                                    NoteBadge(count: notes.count(post.id)).offset(x: 8, y: -9)
                                }
                            }
                            .contentShape(.rect)
                            .onTapGesture { onOpen(post) }
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.top, 18).padding(.leading, 6)
            }
        }
        .padding(.leading, 44)
        .padding(.bottom, isLast ? 0 : 41)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) { Circle().fill(.black).frame(width: 8, height: 8).offset(x: 25, y: 4.5) }
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle().fill(.black.opacity(0.1)).frame(width: 3)
                    .padding(.top, 8.5).padding(.bottom, -28.5).offset(x: 27.5)
            }
        }
        .padding(.top, 20)
    }
}
