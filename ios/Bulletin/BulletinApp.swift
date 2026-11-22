import SwiftUI

@main
struct BulletinApp: App {
    @State private var store = BoardStore()
    @State private var friends = FriendsStore()
    @State private var stickers = StickerStore()
    @State private var notes = NotesStore()

    @AppStorage("introDone") private var introDone = false
    @State private var showIntro: Bool

    init() {
        Typo.registerFonts()
        #if DEBUG
        // while building, the intro shows on every launch; launch with -skipIntro to go straight to the board
        _showIntro = State(initialValue: !CommandLine.arguments.contains("-skipIntro"))
        #else
        _showIntro = State(initialValue: !UserDefaults.standard.bool(forKey: "introDone"))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    .environment(store)
                    .environment(friends)
                    .environment(stickers)
                    .environment(notes)
                if showIntro {
                    IntroView {
                        introDone = true
                        withAnimation(.easeOut(duration: 0.5)) { showIntro = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.light) // designs are light-only for now
        }
    }
}
