import SwiftUI

struct Friend: Identifiable, Hashable {
    let id = UUID()
    var name: String
    /// Their board has something you haven't seen. Cleared once you've been through the queue.
    var hasNew: Bool
    /// What the queue shows for them (placeholder until the visiting screen is designed).
    var latest: String
    /// Their "currently into", shown on the card at the top of their board.
    var into = "pumpkin spice late"
    /// How they answered this month's prompt. (Everyone gets the same prompt; the app writes it.)
    var answer: PromptAnswer = .text("")
    /// Stand-in for their profile picture until pictures exist: a soft color, picked by name.
    var color: Color { Friend.palette[colorIndex % Friend.palette.count] }
    var colorIndex: Int { Friend.names.firstIndex(of: name) ?? 0 }
}

/// The three ways to answer the monthly prompt: write something, add a photo, or pick a post that is already on your board.
enum PromptAnswer: Hashable {
    case text(String)
    case photo(caption: String)
    case existing
}

extension Friend {
    static let palette: [Color] = [
        Color(red: 0.68, green: 0.88, blue: 0.81),  // mint
        Color(red: 0.98, green: 0.80, blue: 0.84),  // blush
        Color(red: 0.80, green: 0.86, blue: 0.98),  // sky
        Color(red: 0.99, green: 0.90, blue: 0.67),  // butter
        Color(red: 0.86, green: 0.80, blue: 0.97),  // lilac
        Color(red: 0.99, green: 0.83, blue: 0.70),  // peach
    ]
    static let names = ["Maya","Liam","Noah","Emma","Olivia","Ethan","Ava","Sophia","Mia","Lucas","Zoe","Leo"]
    /// Color for the nth person (used where only a count is known, like guest list slots).
    static func color(at i: Int) -> Color { palette[i % palette.count] }
}

/// Friends tab state: people who put you on their list, your own guest list, and the doorbell queue.
@Observable
final class FriendsStore {
    static let guestCap = 20

    var friends: [Friend] = [
        Friend(name: "Maya", hasNew: true, latest: "sunday at the lake", into: "sunday swims", answer: .text("my cat asleep in a sunbeam")),
        Friend(name: "Liam", hasNew: true, latest: "new haircut!!", into: "sourdough", answer: .photo(caption: "tiny dog!")),
        Friend(name: "Noah", hasNew: false, latest: "", into: "film cameras", answer: .existing),
        Friend(name: "Emma", hasNew: true, latest: "made soup for everyone", into: "soup season", answer: .text("dad’s terrible puns")),
        Friend(name: "Olivia", hasNew: false, latest: "", into: "matcha everything", answer: .photo(caption: "sis called")),
        Friend(name: "Ethan", hasNew: false, latest: "", into: "trail running", answer: .existing),
        Friend(name: "Ava", hasNew: true, latest: "finally finished the book", into: "pottery class", answer: .text("a library book with notes in it")),
        Friend(name: "Sophia", hasNew: false, latest: "", into: "zines", answer: .photo(caption: "it bloomed")),
        Friend(name: "Mia", hasNew: false, latest: "", into: "pumpkin spice latte", answer: .existing),
        Friend(name: "Lucas", hasNew: false, latest: "", into: "synth music", answer: .text("a really good sandwich")),
        Friend(name: "Zoe", hasNew: false, latest: "", into: "thrifting", answer: .photo(caption: "kitchen disco")),
        Friend(name: "Leo", hasNew: false, latest: "", into: "board games", answer: .existing),
    ]

    /// How many people are on your guest list (they can see your bulletin).
    var guestCount = 17
    /// Someone who put you on their list and hasn't been answered. Nil once added or skipped.
    var addBack: Friend?  = Friend(name: "Maya", hasNew: false, latest: "", into: "sunday swims", answer: .text("my cat asleep in a sunbeam"))

    /// What each friend has on their board (placeholder content until real boards exist).
    private(set) var boards: [Friend.ID: [BoardDay]] = [:]

    init() {
        for (i, f) in friends.enumerated() {
            var posts = [Post(kind: .photo(caption: f.latest.isEmpty ? "Rained all day" : f.latest), rotation: -2.41, image: SamplePhotos.image(i))]
            switch f.answer {
            case .text(let t): posts.append(Post(kind: .sticky(text: t), rotation: 1.8, isPromptAnswer: true))
            case .photo(let c): posts.append(Post(kind: .photo(caption: c), rotation: 2.4, isPromptAnswer: true, image: SamplePhotos.image(i + 2)))
            case .existing: posts[0].isPromptAnswer = true
            }
            boards[f.id] = [BoardDay(id: 4, posts: posts), BoardDay(id: 3, posts: [])]
        }
    }

    var spotsLeft: Int { Self.guestCap - guestCount }
    var isFull: Bool { guestCount >= Self.guestCap }

    /// Friends with news first (keeping their order), then everyone else.
    var ordered: [Friend] { friends.filter(\.hasNew) + friends.filter { !$0.hasNew } }
    var withNews: [Friend] { friends.filter(\.hasNew) }

    func addBackTapped() {
        guard !isFull, addBack != nil else { return }
        guestCount += 1
        addBack = nil
    }

    /// A silent "not now": no one is told.
    func skipAddBack() { addBack = nil }

    func markSeen(_ id: Friend.ID) {
        guard let i = friends.firstIndex(where: { $0.id == id }) else { return }
        friends[i].hasNew = false
    }
}
