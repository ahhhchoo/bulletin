import SwiftUI

enum PostKind: Hashable {
    /// Seed content from the design: a colored photo block with a caption slip.
    case photo(caption: String)
    case sticky(text: String)
}

struct Post: Identifiable, Hashable {
    let id = UUID()
    var kind: PostKind
    var rotation: Double          // degrees; items are loose and a little tilted
    var isPromptAnswer = false
}

struct BoardDay: Identifiable {
    let id: Int                   // day of month
    let label: String
    var posts: [Post]
}

@Observable
final class BoardStore {
    var days: [BoardDay] = [
        BoardDay(id: 2, label: "Mon 2", posts: [
            Post(kind: .photo(caption: "Rained all day"), rotation: -2.41)
        ]),
        BoardDay(id: 3, label: "Tues 3", posts: [])
    ]

    var currentlyInto = "pumpkin spice late"
    let prompt = "what made you smile lately?"

    /// Set when the user taps the prompt card's "+": the next post answers it.
    var answeringPrompt = false
    var promptAnswerID: Post.ID?

    var postCount = 0             // drives haptics

    func addSticky(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let today = days.indices.last else { return }
        var post = Post(kind: .sticky(text: trimmed), rotation: .random(in: -3...3))
        if answeringPrompt {
            post.isPromptAnswer = true
            promptAnswerID = post.id
            answeringPrompt = false
        }
        days[today].posts.append(post)
        postCount += 1
    }
}
