import SwiftUI

@main
struct BulletinApp: App {
    @State private var store = BoardStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .preferredColorScheme(.light) // designs are light-only for now
        }
    }
}
