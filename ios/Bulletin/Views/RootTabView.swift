import SwiftUI

struct RootTabView: View {
    @Environment(BoardStore.self) private var board
    @Environment(FriendsStore.self) private var friends
    @Environment(NotesStore.self) private var notes
    @Environment(TipsStore.self) private var tips
    @Environment(ShelfStore.self) private var shelf
    @Environment(AuthService.self) private var auth
    @Environment(ProfileStore.self) private var profile
    @Environment(PostService.self) private var postService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private enum Page { case bulletin, friends, shelf }
    @State private var page: Page = .bulletin
    @State private var sharing = false
    /// The seal ritual's naming step, shown for a finished month that hasn't been sealed yet.
    @State private var sealing: SealingMonth?
    /// Months the person closed the naming screen on; they are asked again next time the app opens.
    @State private var skipped: Set<String> = []

    private struct SealingMonth: Identifiable {
        let key: String
        let days: [BoardDay]
        var id: String { key }
    }
    private var nextSeal: String? { board.pendingSeals.first { !skipped.contains($0) } }

    var body: some View {
        TabView(selection: $page) {
            Tab("bulletin", image: "TabNote", value: Page.bulletin) {
                BoardView()
            }
            // a smile when it is not the page you are on; the open-mouthed face when it is
            Tab(value: Page.friends) {
                FriendsView()
            } label: {
                Label {
                    Text("friends")
                } icon: {
                    Image(page == .friends ? "TabFriends" : "TabFriendsSmile")
                }
            }
            Tab("shelf", image: "TabShelf", value: Page.shelf) {
                ShelfView()
            }
        }
        // the app is up, so it is safe to start Firebase Auth; then pick up the server's prompt for the month
        .task(id: auth.uid) {
            auth.start()
            await board.refreshPrompt()
        }
        // coming back to the app on a new day (or month): move the board along
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await board.dayMayHaveChanged(); await board.refreshPrompt() } }
        }
        // someone who has signed up: save their posts to the server and bring them down
        .task(id: auth.uid.map { $0 + (profile.isSignedUp ? "+" : "") }) {
            if let uid = auth.uid, profile.isSignedUp {
                let records = await board.connect(uid: uid, service: postService)
                await shelf.load(records, uid: uid, service: postService)
            } else {
                board.disconnect()
            }
        }
        // a finished month is waiting to be sealed: bring its posts down and ask for a name and a cover
        .task(id: nextSeal) {
            guard let key = nextSeal, let uid = auth.uid, sealing == nil else { return }
            let loaded = (try? await postService.loadDays(uid: uid, month: key)) ?? []
            let days = await postService.withThumbnails(loaded)
            if days.allSatisfy({ $0.posts.isEmpty }) {
                // nothing was pinned that month: seal it quietly, it doesn't go on the shelf
                await shelf.seal(monthKey: key, days: days, title: "", cover: nil, notes: { _ in 0 }, service: postService, uid: uid)
                board.pendingSeals.removeAll { $0 == key }
            } else {
                sealing = SealingMonth(key: key, days: days)
            }
        }
        .onAppear { notes.seedIfNeeded(board: board, friends: friends) }
        .fullScreenCover(item: $sealing) { month in
            let name = BoardCalendar.monthName(forKey: month.key)
            NameMonthView(heading: "Name \(name)", photos: month.days.flatMap(\.posts).compactMap(\.image), saveLabel: "Seal \(name)",
                          onSkip: { seal(month, title: "", cover: nil) },
                          onSave: { seal(month, title: $0, cover: $1) },
                          onCancel: { skipped.insert(month.key); sealing = nil })
        }
        .overlay(alignment: .bottom) { tabTip }
        // the invite link goes out through the share sheet; the tip stays until something was really sent
        .sheet(isPresented: $sharing) {
            ActivityView(items: ["Join me on Bulletin", tips.inviteURL]) { sent in
                sharing = false
                if sent { tips.finishInvite() }
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// Seals the month on the server, puts it on the shelf, and moves on to the next waiting month (or the shelf).
    private func seal(_ month: SealingMonth, title: String, cover: PostImage?) {
        sealing = nil
        Task {
            await shelf.seal(monthKey: month.key, days: month.days, title: title, cover: cover, notes: { notes.count($0) },
                             service: postService, uid: auth.uid)
            board.pendingSeals.removeAll { $0 == month.key }
            if nextSeal == nil { page = .shelf }
        }
    }

    /// Tips that point at, or sit above, the tab bar: inviting people, and the notifications question.
    @ViewBuilder private var tabTip: some View {
        let width = min(UIScreen.main.bounds.width - 40, 346)
        Group {
            switch tips.step {
            case .invite:
                TipBubble(title: "That’s your first one.",
                          message: "Bulletin is better with a few people. Send a private link: it works for one person and lasts a week.",
                          arrow: .down(x: width / 2), width: width) {
                    HStack(spacing: 8) {
                        Button { sharing = true } label: { TipButton(title: "Invite someone") }
                            .buttonStyle(.plain)
                        TipGhostButton(title: "Later") { tips.finishInvite() }
                    }
                }
                .transition(TipBubble<EmptyView>.appear(from: .bottom, reduceMotion: reduceMotion))
            case .note:
                TipBubble(title: "\(tips.noteFrom) left you a note.",
                          message: "Want a heads-up when that happens? We’ll only buzz you for notes, never for anything else.",
                          width: width) {
                    HStack(spacing: 8) {
                        Button { tips.allowNotifications() } label: { TipButton(title: "Turn on notifications") }
                            .buttonStyle(.plain)
                        TipGhostButton(title: "Not now") { tips.notNow() }
                    }
                }
                .transition(TipBubble<EmptyView>.appear(from: .bottom, reduceMotion: reduceMotion))
            default:
                EmptyView()
            }
        }
        .padding(.bottom, 112)
    }
}
