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
    /// When they last posted: shown under their block on the Friends tab.
    var lastPosted = Date()
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
    static let guestCap = 10

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

    /// The people on your guest list (they can see your bulletin).
    var guests: [Guest] = (0..<8).map { Guest(name: Friend.names[$0 % Friend.names.count], colorIndex: $0) }
    var guestCount: Int { guests.count }
    /// Someone who put you on their list and hasn't been answered. Nil once added or skipped.
    var addBack: Friend?  = Friend(name: "Maya", hasNew: false, latest: "", into: "sunday swims", answer: .text("my cat asleep in a sunbeam"))

    /// What happened since you last looked: notes on your photos, replies to your notes. Shown on the Guests page.
    var activity: [Activity] = {
        let now = Date()
        return [
            Activity(who: "Liam", text: "left a note on your photo", when: now.addingTimeInterval(-3_000), unread: true),
            Activity(who: "Maya", text: "replied to your note on her photo", when: now.addingTimeInterval(-9_500), unread: true),
            Activity(who: "Emma", text: "left a note on your photo", when: now.addingTimeInterval(-21_000), unread: true),
            Activity(who: "Noah", text: "replied to your note on his photo", when: now.addingTimeInterval(-100_000), unread: false),
            Activity(who: "Ava", text: "left a note on your photo", when: now.addingTimeInterval(-190_000), unread: false),
        ]
    }()
    var unreadActivity: Int { activity.filter(\.unread).count }
    /// The dot on the person button: a request waiting, or activity you have not seen.
    var needsAttention: Bool { addBack != nil || unreadActivity > 0 }
    /// What a new person sees: nobody yet. The sample friends are only for the designs.
    func startFresh() {
        friends = []
        guests = []
        addBack = nil
        activity = []
    }

    func markActivityRead() { for i in activity.indices { activity[i].unread = false } }

    /// What each friend has on their board (placeholder content until real boards exist).
    private(set) var boards: [Friend.ID: [BoardDay]] = [:]

    init() {
        for (i, f) in friends.enumerated() {
            var posts = [Post(kind: .photo(caption: f.latest.isEmpty ? "Rained all day" : f.latest), rotation: -2.41, image: SamplePhotos.image(i))]
            switch f.answer {
            // the prompt answer was posted first; the photo went up later in the day, so it is their latest
            case .text(let t):
                var sticky = Post(kind: .sticky(text: t), rotation: 1.8, isPromptAnswer: true)
                sticky.stickyColor = StickyColor.allCases[i % StickyColor.allCases.count]
                posts.insert(sticky, at: 0)
            case .photo(let c): posts.insert(Post(kind: .photo(caption: c), rotation: 2.4, isPromptAnswer: true, image: SamplePhotos.image(i + 2)), at: 0)
            case .existing: posts[0].isPromptAnswer = true
            }
            // oldest day first, like your own board: it ends at the newest
            boards[f.id] = [BoardDay(id: 3, posts: []), BoardDay(id: 4, posts: posts)]
        }
        // spread their last posts over the past few weeks: the ones with news posted most recently
        let now = Date()
        for i in friends.indices {
            let ago = friends[i].hasNew ? Double(i) * 3_600 + 600 : Double(i + 2) * 86_400 + 4_000
            friends[i].lastPosted = now.addingTimeInterval(-ago)
            // their newest post is the last of the day, as on your own board: the one the Friends tab shows, so it carries that same time; earlier ones a few hours before
            if var days = boards[friends[i].id], let d = days.lastIndex(where: { !$0.posts.isEmpty }) {
                let count = days[d].posts.count
                for k in 0..<count {
                    days[d].posts[k].postedAt = friends[i].lastPosted.addingTimeInterval(-Double(count - 1 - k) * 7_200)
                }
                boards[friends[i].id] = days
            }
        }
    }

    var spotsLeft: Int { Self.guestCap - guestCount }
    var isFull: Bool { guestCount >= Self.guestCap }

    /// Friends with news first (keeping their order), then everyone else.
    var ordered: [Friend] { friends.filter(\.hasNew) + friends.filter { !$0.hasNew } }
    var withNews: [Friend] { friends.filter(\.hasNew) }

    func addBackTapped() {
        guard !isFull, addBack != nil else { return }
        guests.append(Guest(name: addBack?.name ?? "friend", colorIndex: guests.count))
        addBack = nil
    }

    /// Add someone by username from the Edit sheet. Does nothing when the list is full or they are already on it.
    func addGuest(name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isFull, !guests.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }
        guests.append(Guest(name: name, colorIndex: guests.count))
    }

    func removeGuest(_ id: Guest.ID) { guests.removeAll { $0.id == id } }

    /// The most recent thing on a friend's board, for their block: the last post of their newest day with posts. Boards run
    /// oldest to newest, like yours, so that is the one at the very bottom. The rest of the day is the stack behind it.
    func latestPost(of friend: Friend) -> Post? {
        boards[friend.id]?.last { !$0.posts.isEmpty }?.posts.last
    }

    /// How many posts their newest day holds: more than one shows as a stack on their block.
    func latestDayCount(of friend: Friend) -> Int {
        boards[friend.id]?.last { !$0.posts.isEmpty }?.posts.count ?? 0
    }

    /// A silent "not now": no one is told.
    func skipAddBack() { addBack = nil }

    func markSeen(_ id: Friend.ID) {
        guard let i = friends.firstIndex(where: { $0.id == id }) else { return }
        friends[i].hasNew = false
    }
}

/// Someone on your guest list. (Stand-in for a real account until profiles exist.)
struct Guest: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var colorIndex: Int
    var color: Color { Friend.color(at: colorIndex) }
}

/// One line in the activity list on the Guests page.
struct Activity: Identifiable, Hashable {
    let id = UUID()
    var who: String
    var text: String
    var when: Date
    var unread: Bool
    var color: Color { Friend.color(at: Friend.names.firstIndex(of: who) ?? 0) }
}
