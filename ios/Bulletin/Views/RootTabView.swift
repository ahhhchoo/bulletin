import SwiftUI

struct RootTabView: View {
    @Environment(BoardStore.self) private var board
    @Environment(FriendsStore.self) private var friends
    @Environment(NotesStore.self) private var notes

    private enum Page { case bulletin, friends, shelf }
    @State private var page: Page = .bulletin

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
                ContentUnavailableView(
                    "Shelf",
                    systemImage: "books.vertical",
                    description: Text("Sealed months stack up here. ARC-01 isn't designed yet.")
                )
            }
        }
        .onAppear { notes.seedIfNeeded(board: board, friends: friends) }
    }
}
