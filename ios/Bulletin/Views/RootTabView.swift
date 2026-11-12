import SwiftUI

struct RootTabView: View {
    @Environment(BoardStore.self) private var board
    @Environment(FriendsStore.self) private var friends
    @Environment(NotesStore.self) private var notes

    var body: some View {
        TabView {
            Tab("bulletin", image: "TabNote") {
                BoardView()
            }
            Tab("friends", image: "TabFriends") {
                FriendsView()
            }
            Tab("shelf", image: "TabShelf") {
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
