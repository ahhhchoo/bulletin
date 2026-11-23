import SwiftUI

struct RootTabView: View {
    @Environment(BoardStore.self) private var board
    @Environment(FriendsStore.self) private var friends
    @Environment(NotesStore.self) private var notes
    @Environment(TipsStore.self) private var tips
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Page { case bulletin, friends, shelf }
    @State private var page: Page = .bulletin
    @State private var sharing = false

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
        .onAppear { notes.seedIfNeeded(board: board, friends: friends) }
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
