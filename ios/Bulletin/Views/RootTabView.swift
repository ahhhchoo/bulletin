import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("bulletin", image: "TabNote") {
                BoardView()
            }
            Tab("friends", image: "TabFriends") {
                ContentUnavailableView(
                    "Friends",
                    systemImage: "person.2",
                    description: Text("Doorbell and boards you can see. FRN-01 isn't designed yet.")
                )
            }
            Tab("shelf", image: "TabShelf") {
                ContentUnavailableView(
                    "Shelf",
                    systemImage: "books.vertical",
                    description: Text("Sealed months stack up here. ARC-01 isn't designed yet.")
                )
            }
        }
    }
}
