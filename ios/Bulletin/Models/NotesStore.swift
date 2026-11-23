import SwiftUI

/// A note a friend left on a photo. It lives in the layer under the photo, never on the board itself.
struct PostNote: Identifiable, Hashable {
    let id = UUID()
    var by: String
    var text: String
    /// The owner's answer: one per note, one level deep.
    var reply: String?
    /// Left by you (when you are the visitor), so you can take it back.
    var mine = false
    /// Rewritten after it was stuck on.
    var edited = false
}

/// Friends' notes on photos, for your own board and for the boards you visit.
@Observable
final class NotesStore {
    private var byPost: [Post.ID: [PostNote]] = [:]
    private var seeded = false

    func notes(_ post: Post.ID) -> [PostNote] { byPost[post] ?? [] }
    func count(_ post: Post.ID) -> Int { byPost[post]?.count ?? 0 }

    /// One note per person per photo: writing again replaces yours.
    func addMine(_ text: String, to post: Post.ID) {
        var list = byPost[post] ?? []
        list.removeAll { $0.mine }
        list.append(PostNote(by: "You", text: text, mine: true))
        byPost[post] = list
    }

    /// Rewrites the note you left; it keeps its place and says it was edited.
    func editMine(_ text: String, on post: Post.ID) {
        guard let i = byPost[post]?.firstIndex(where: \.mine) else { return }
        byPost[post]?[i].text = text
        byPost[post]?[i].edited = true
    }

    func takeBack(on post: Post.ID) { byPost[post]?.removeAll { $0.mine } }

    func reply(_ text: String, to note: PostNote.ID, on post: Post.ID) {
        guard let i = byPost[post]?.firstIndex(where: { $0.id == note }) else { return }
        byPost[post]?[i].reply = text
    }

    /// Hidden from everyone, and the sender is not told.
    func tuck(_ note: PostNote.ID, on post: Post.ID) { byPost[post]?.removeAll { $0.id == note } }

    /// Sample notes so there is something to look at until real ones exist.
    func seedIfNeeded(board: BoardStore, friends: FriendsStore) {
        guard !seeded else { return }
        seeded = true
        if let photo = board.days.flatMap(\.posts).first(where: { if case .photo = $0.kind { true } else { false } }) {
            byPost[photo.id] = [
                PostNote(by: "Liam", text: "that looks so good"),
                PostNote(by: "Emma", text: "where is this?? i need to go"),
                PostNote(by: "Noah", text: "save me one", reply: "thai place on 5th"),
                PostNote(by: "Ava", text: "omg the sauce"),
            ]
        }
        let samples: [[PostNote]] = [
            [PostNote(by: "Noah", text: "so cozy!!"), PostNote(by: "Mia", text: "i can smell this from here")],
            [PostNote(by: "Zoe", text: "jealous")],
            [PostNote(by: "Leo", text: "recipe please"), PostNote(by: "Sophia", text: "take me next time"), PostNote(by: "Lucas", text: "dinner of the year")],
        ]
        for (f, notes) in zip(friends.friends.prefix(3), samples) {
            if let photo = friends.boards[f.id]?.first?.posts.first { byPost[photo.id] = notes }
        }
    }
}
