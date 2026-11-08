import SwiftUI

enum PostKind: Hashable {
    /// Seed content from the design: a colored photo block with a caption slip.
    case photo(caption: String)
    case sticky(text: String)
    /// Long entries become a page with an optional title (shown on the board as a folded note).
    case journal(title: String, body: String)
}

struct Post: Identifiable, Hashable {
    let id = UUID()
    var kind: PostKind
    var rotation: Double          // degrees; items are loose and a little tilted
    var isPromptAnswer = false
    /// Added to a past day: gets a paperclip instead of a pushpin.
    var isClipped = false
}

struct BoardDay: Identifiable {
    let id: Int                   // day of month
    var posts: [Post]
}

@Observable
final class BoardStore {
    /// Nov 2026. Nov 1 is a Sunday. "Today" is Tues 3, as in the designs.
    let todayID = 3
    private static let weekdays = ["Sun", "Mon", "Tues", "Wed", "Thu", "Fri", "Sat"]

    var days: [BoardDay] = [
        BoardDay(id: 2, posts: [
            Post(kind: .photo(caption: "Rained all day"), rotation: -2.41)
        ]),
        BoardDay(id: 3, posts: [])
    ]

    var currentlyInto = "pumpkin spice late"
    let prompt = "what made you smile lately?"

    /// Set when the user taps the prompt card's "+": the next post answers it.
    var answeringPrompt = false
    var promptAnswerID: Post.ID?

    var postCount = 0             // drives haptics

    // MARK: labels

    func shortLabel(_ id: Int) -> String { "\(Self.weekdays[(id - 1) % 7]) \(id)" }       // "Mon 2"
    func fullLabel(_ id: Int) -> String { "\(Self.weekdays[(id - 1) % 7]) 11/\(id)" }     // "Mon 11/2"

    /// Days you can post to: this month, up to today. Newest first.
    var postableDays: [Int] { Array((1...todayID).reversed()) }

    // MARK: posting

    func addPost(title: String, body: String, dayID: Int, asJournal: Bool) {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, (1...todayID).contains(dayID) else { return }

        var post = Post(
            kind: asJournal
                ? .journal(title: title.trimmingCharacters(in: .whitespacesAndNewlines), body: text)
                : .sticky(text: text),
            rotation: .random(in: -3...3)
        )
        post.isClipped = dayID != todayID
        if answeringPrompt {
            post.isPromptAnswer = true
            promptAnswerID = post.id
            answeringPrompt = false
        }

        if let i = days.firstIndex(where: { $0.id == dayID }) {
            days[i].posts.append(post)
        } else {
            // a day with no row yet: add it in order
            let at = days.firstIndex(where: { $0.id > dayID }) ?? days.endIndex
            days.insert(BoardDay(id: dayID, posts: [post]), at: at)
        }
        postCount += 1
    }
}
