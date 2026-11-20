import SwiftUI

/// A friend's board: their look and their days. Nothing on it asks you to join in: to say something about a photo,
/// open it and go down a layer (see `NotesLayers`).
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

    @State private var openPost: Post?
    @State private var showAnswer = false
    @GestureState private var touching = false

    private var isBusy: Bool { openPost != nil || showAnswer || touching }
    private var days: [BoardDay] { store.boards[friend.id] ?? [] }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // the same prompt card as your own board: paper with rounded bottom corners over black
                VStack(spacing: 0) {
                    header
                    cards.padding(.top, 14).padding(.bottom, 22)
                }
                .frame(maxWidth: .infinity)
                .background(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24, style: .continuous)
                    .fill(Color("Paper")).ignoresSafeArea(edges: .top))
                sheet.padding(.top, 9)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                    DayBlock(day: day, isLast: i == days.count - 1, highlightNew: friend.hasNew && i == 0) { post in
                        withAnimation(.snappy) { openPost = post }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 560, alignment: .topLeading)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .simultaneousGesture(DragGesture(minimumDistance: 0).updating($touching) { _, s, _ in s = true })
        .frame(maxWidth: .infinity)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
        .background(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
            .fill(Color("Paper")).ignoresSafeArea(edges: .bottom))
    }
}

private struct DayBlock: View {
    @Environment(BoardStore.self) private var board
    @Environment(NotesStore.self) private var notes
    let day: BoardDay
    let isLast: Bool
    let highlightNew: Bool
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
                            .overlay(alignment: .topLeading) {
                                if highlightNew {
                                    Text("new").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Color("DayPink"), in: Capsule()).offset(x: -4, y: -4)
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
