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
    /// Shown when you tap the paperclip, e.g. "Tues 3 at 9:14 PM". Only set for clipped posts.
    var addedLabel: String?

    /// Rough height on the board, used to decide when a day gets busy. Close enough beats measuring.
    var estimatedHeight: CGFloat {
        switch kind {
        case .photo: 190
        case .sticky: 150
        case .journal: 156
        }
    }
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
            Post(kind: .photo(caption: "Rained all day"), rotation: -2.41),
            Post(kind: .photo(caption: "this is a picture"), rotation: 2.6),
            Post(kind: .sticky(text: "Watching this ever-so exciting movie that is about a group of elderly people who get together on Thursdays"), rotation: -1.2),
            Post(kind: .journal(title: "short rant", body: "Watching this ever-so exciting movie that is about a group of elderly people who get together on Thursdays to solve cold murder cases."), rotation: 2.2),
            Post(kind: .journal(title: "short rant", body: "Watching this ever-so exciting movie that is about a group of elderly people who get together on Thursdays to solve cold murder cases."), rotation: -2.0),
            Post(kind: .journal(title: "short rant", body: "Watching this ever-so exciting movie that is about a group of elderly people who get together on Thursdays to solve cold murder cases."), rotation: 1.4),
        ]),
        BoardDay(id: 3, posts: [])
    ]

    var currentlyInto = "pumpkin spice late"
    let prompt = "what made you smile lately?"

    /// Set when the user taps the prompt card's "+": the next post answers it.
    var answeringPrompt = false
    var promptAnswerID: Post.ID?

    /// Busy days that are currently opened out. Everything else folds its overflow into a stack.
    var expandedDays: Set<Int> = []

    // What the user is doing with an existing post (tap to open, long-press for the menu)
    var openedPostID: Post.ID?            // sticky or photo opened as a card in place
    var openedFrame: CGRect = .zero       // where it was on screen, so the card grows from there
    var openedJournalID: Post.ID?         // folded notes open as a full page
    var editRequest: Post.ID?
    var deleteRequest: Post.ID?
    var captionRequest: Post.ID?

    var postCount = 0             // drives haptics
    var lastPostedDayID: Int?     // where the board scrolls to after posting

    // MARK: labels

    func shortLabel(_ id: Int) -> String { "\(Self.weekdays[(id - 1) % 7]) \(id)" }       // "Mon 2"
    func fullLabel(_ id: Int) -> String { "\(Self.weekdays[(id - 1) % 7]) 11/\(id)" }     // "Mon 11/2"

    /// Days you can post to: this month, up to today. Newest first.
    var postableDays: [Int] { Array((1...todayID).reversed()) }

    // MARK: busy days

    /// A day shows about two rows before the rest folds into a stack.
    static let dayHeightBudget: CGFloat = 380

    /// Which posts stay visible when a day is folded: as many whole rows (two across, in posting
    /// order) as fit the height budget, plus prompt answers, which never go in the stack.
    static func visibleIndices(in posts: [Post]) -> Set<Int> {
        var keep = Set<Int>()
        var used: CGFloat = 0
        var i = 0
        while i < posts.count {
            let row = posts[i..<min(i + 2, posts.count)]
            let rowHeight = row.map(\.estimatedHeight).max() ?? 0
            if used + rowHeight > dayHeightBudget && i > 0 { break }
            used += rowHeight
            for k in i..<min(i + 2, posts.count) { keep.insert(k) }
            i += 2
        }
        for (k, post) in posts.enumerated() where post.isPromptAnswer { keep.insert(k) }
        return keep
    }

    // MARK: existing posts

    func post(_ id: Post.ID) -> Post? { days.lazy.flatMap(\.posts).first { $0.id == id } }

    func dayID(of id: Post.ID) -> Int? { days.first { $0.posts.contains { $0.id == id } }?.id }

    func delete(_ id: Post.ID) {
        guard let d = days.firstIndex(where: { $0.posts.contains { $0.id == id } }) else { return }
        days[d].posts.removeAll { $0.id == id }
        if promptAnswerID == id { promptAnswerID = nil }
        // a past day with nothing left disappears; today always keeps its row
        if days[d].posts.isEmpty && days[d].id != todayID { days.remove(at: d) }
    }

    /// Drag to reorder: dropping onto another post of the same day puts it in that post's place.
    /// Posts never change day by dragging.
    @discardableResult
    func reorder(_ id: Post.ID, onto target: Post.ID) -> Bool {
        guard id != target,
              let d = days.firstIndex(where: { $0.posts.contains { $0.id == id } && $0.posts.contains { $0.id == target } }),
              let from = days[d].posts.firstIndex(where: { $0.id == id }),
              let to = days[d].posts.firstIndex(where: { $0.id == target })
        else { return false }
        let moved = days[d].posts.remove(at: from)
        days[d].posts.insert(moved, at: to)
        return true
    }

    /// Edit in place: no "edited" marker, as in the rules.
    func update(_ id: Post.ID, title: String, body: String, asJournal: Bool) {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let d = dayID(of: id),
              let i = days.firstIndex(where: { $0.id == d }),
              let p = days[i].posts.firstIndex(where: { $0.id == id }) else { return }
        days[i].posts[p].kind = asJournal
            ? .journal(title: title.trimmingCharacters(in: .whitespacesAndNewlines), body: text)
            : .sticky(text: text)
        postCount += 1
    }

    func updateCaption(_ id: Post.ID, caption: String) {
        guard let d = dayID(of: id),
              let i = days.firstIndex(where: { $0.id == d }),
              let p = days[i].posts.firstIndex(where: { $0.id == id }) else { return }
        days[i].posts[p].kind = .photo(caption: caption.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func expand(_ dayID: Int) { expandedDays.insert(dayID) }
    func collapse(_ dayID: Int) { expandedDays.remove(dayID) }

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
        if post.isClipped {
            let time = Date.now.formatted(date: .omitted, time: .shortened)
            post.addedLabel = "\(shortLabel(todayID)) at \(time)"
        }
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
        if let i = days.firstIndex(where: { $0.id == dayID }),
           !Self.visibleIndices(in: days[i].posts).contains(days[i].posts.count - 1) {
            expandedDays.insert(dayID)
        }
        lastPostedDayID = dayID
        postCount += 1
    }
}
