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
            Color("Paper").ignoresSafeArea()
            VStack(spacing: 0) {
                header
                cards.padding(.top, 12)
                sheet.padding(.top, 17)
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
        HStack(spacing: 8) {
            BigWord(label: "currently into", value: friend.into, size: 18)
                .frame(width: 152, height: 83, alignment: .leading)
                .background(Color("CardInto"), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            promptCard
        }
        .padding(.horizontal, 12)
    }

    private var answerPost: Post? { days.flatMap(\.posts).first(where: \.isPromptAnswer) }

    /// Everyone gets the same prompt, written by the app. The friend's answer is their reply; tap it to read it in full.
    private var promptCard: some View {
        PromptChat(question: board.prompt, answer: answerPost, onAnswer: { showAnswer = true })
            .frame(maxWidth: .infinity)
            .frame(height: 83)
            .background(Color("CardPrompt"), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .popover(isPresented: $showAnswer, arrowEdge: .top) {
                if let post = answerPost {
                    PostView(post: post, animated: false, tilt: 0)
                        .padding(24)
                        .presentationCompactAdaptation(.popover)
                }
            }
    }

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
        .background(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
            .fill(.white).ignoresSafeArea(edges: .bottom))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
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
                                    NoteBadge(count: notes.count(post.id)).offset(x: 10, y: -10)
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
