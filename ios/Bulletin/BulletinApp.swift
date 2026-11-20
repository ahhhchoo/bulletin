import SwiftUI

@main
struct BulletinApp: App {
    @State private var store = BoardStore()
    @State private var friends = FriendsStore()
    @State private var stickers = StickerStore()
    @State private var notes = NotesStore()

    init() { Typo.registerFonts() }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(friends)
                .environment(stickers)
                .environment(notes)
                .preferredColorScheme(.light) // designs are light-only for now
        }
    }
}
