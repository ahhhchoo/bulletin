import SwiftUI

@main
struct BulletinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: BoardStore
    @State private var friends: FriendsStore
    @State private var stickers = StickerStore()
    @State private var notes = NotesStore()
    @State private var profile = ProfileStore()
    @State private var tips = TipsStore()
    @State private var shelf: ShelfStore
    @State private var postService = PostService()
    @State private var auth = AuthService()
    @State private var profileService = ProfileService()

    @AppStorage("introDone") private var introDone = false
    @State private var showIntro: Bool
    @State private var signUp: SignUpMethod?

    init() {
        // Someone who has already signed up opens straight to their own (empty until it loads) board, not the sample one.
        let board = BoardStore(), friendsStore = FriendsStore(), shelfStore = ShelfStore()
        if UserDefaults.standard.bool(forKey: "introDone") {
            board.startFresh(); friendsStore.startFresh(); shelfStore.startFresh()
        }
        _store = State(initialValue: board)
        _friends = State(initialValue: friendsStore)
        _shelf = State(initialValue: shelfStore)
        Typo.registerFonts()
        #if DEBUG
        // while building, the intro shows on every launch; launch with -skipIntro to go straight to the board
        _showIntro = State(initialValue: !CommandLine.arguments.contains("-skipIntro"))
        // launch with -signUp (or -signUpApple) to open sign-up directly
        if CommandLine.arguments.contains("-signUp") { _signUp = State(initialValue: .phone) }
        if CommandLine.arguments.contains("-signUpApple") { _signUp = State(initialValue: .apple) }
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
                    .environment(profile)
                    .environment(tips)
                    .environment(shelf)
                    .environment(auth)
                    .environment(profileService)
                    .environment(postService)
                if showIntro {
                    IntroView { method in
                        withAnimation(.easeOut(duration: 0.35)) { signUp = method }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
                if let method = signUp {
                    SignUpView(method: method) {
                        withAnimation(.easeOut(duration: 0.3)) { signUp = nil }
                    } onFinish: {
                        introDone = true
                        store.startFresh()        // a new board is empty and nothing is set; the tips start there
                        friends.startFresh()
                        shelf.startFresh()
                        withAnimation(.easeOut(duration: 0.5)) { showIntro = false; signUp = nil }
                        tips.begin()
                    }
                    .environment(profile)
                    .environment(auth)
                    .environment(profileService)
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .preferredColorScheme(.light) // designs are light-only for now
            #if DEBUG
            .task {
                // -tips starts the tips on the board; -tipNote shows the notifications question a few seconds later
                if CommandLine.arguments.contains("-tips") { store.startFresh(); friends.startFresh(); shelf.startFresh(); tips.begin() }
                if CommandLine.arguments.contains("-emptyShelf") { shelf.startFresh() }
                if CommandLine.arguments.contains("-tipInvite") { store.startFresh(); tips.debugShow(.invite) }
                if CommandLine.arguments.contains("-tipNote") {
                    try? await Task.sleep(for: .seconds(2.5))
                    tips.noteArrived(by: "Maya")
                }
            }
            #endif
        }
    }
}
