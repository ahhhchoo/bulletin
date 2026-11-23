import SwiftUI

enum PhotoMetrics {
    /// Photos are pinned at a fixed width; their height follows the picture's shape.
    static let pinWidth: CGFloat = 128
    /// The most a caption can hold. The board shows two lines of it; the opened photo shows it all.
    static let captionLimit = 200
    /// About how many characters fit on one line of the caption slip, for estimating its height.
    static let captionCharsPerLine = 17
}

/// A photo on a post. Wraps the image so `Post` can stay Hashable (identity is the id).
struct PostImage: Hashable, Identifiable {
    let id = UUID()
    /// The small picture: what feeds, board tiles and the Shared tab show.
    let uiImage: UIImage
    /// The bigger one, shown only when a post is opened. The same as `uiImage` for pictures that were never optimized.
    let full: UIImage
    /// Set for a GIF: the shrunk GIF itself, played when the post is opened.
    let gifData: Data?
    /// Set for a GIF: the small animation that plays in feeds and tiles (`uiImage` is its still first frame).
    let feedGIF: Data?
    /// The optimized bytes, kept so the post can be uploaded as they are.
    let media: ProcessedMedia?
    /// Where this picture lives on the server. Set once it is uploaded, or for a post loaded from there.
    var remote: StoredMedia?
    /// False for a post loaded from the server until its thumbnail has arrived (`uiImage` is a blank of the right shape).
    var hasThumbnail = true

    var isAnimated: Bool { gifData != nil || remote?.isAnimated == true }

    init(uiImage: UIImage) {
        self.uiImage = uiImage
        self.full = uiImage
        self.gifData = nil
        self.feedGIF = nil
        self.media = nil
        self.remote = nil
    }

    /// A picture that is on the server. Until its thumbnail arrives it is a blank of the right shape, so the board lays
    /// out correctly and nothing jumps when the picture appears.
    init(remote: StoredMedia, thumbnail: UIImage? = nil) {
        let aspect = CGFloat(remote.width) / CGFloat(max(remote.height, 1))
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24 / max(aspect, 0.1))).image { ctx in
            UIColor(white: 0.9, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: ctx.format.bounds.size))
        }
        self.uiImage = thumbnail ?? blank
        self.full = self.uiImage
        self.gifData = nil
        self.feedGIF = nil
        self.media = nil
        self.remote = remote
        self.hasThumbnail = thumbnail != nil
    }

    init?(media: ProcessedMedia) {
        guard let thumb = UIImage(data: media.thumb), let full = UIImage(data: media.full) ?? Optional(thumb) else { return nil }
        self.uiImage = thumb
        self.full = full
        self.gifData = media.kind == .gif ? media.full : nil
        self.feedGIF = media.feed
        self.media = media
        self.remote = nil
    }

    /// Width over height, as shot.
    var aspect: CGFloat { uiImage.size.width / max(uiImage.size.height, 1) }
    /// The shape it is pinned at: the photo's own, but kept within a tall portrait and a wide panorama,
    /// so one extreme photo can't break a day's layout (the picture is cropped a little at the extremes).
    var pinAspect: CGFloat { min(max(aspect, 0.66), 1.6) }

    static func == (lhs: PostImage, rhs: PostImage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension UIImage {
    /// Shrinks a picked photo so the board never holds full-resolution camera images.
    func scaled(maxSide: CGFloat) -> UIImage {
        let factor = min(1, maxSide / max(size.width, size.height))
        guard factor < 1 else { return self }
        let target = CGSize(width: size.width * factor, height: size.height * factor)
        return UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}

enum PostKind: Hashable {
    /// Seed content from the design: a colored photo block with a caption slip.
    case photo(caption: String)
    case sticky(text: String)
    /// Long entries become a page with an optional title (shown on the board as a folded note).
    case journal(title: String, body: String)
}

struct Post: Identifiable, Hashable {
    /// Also the post's name on the server, so a post loaded from there keeps its identity.
    var id = UUID()
    var kind: PostKind
    var rotation: Double          // degrees; items are loose and a little tilted
    var isPromptAnswer = false
    /// The paper color, for stickies.
    var stickyColor: StickyColor = .yellow
    /// The picture, for photo posts. Seed photos have none and show a placeholder color block.
    var image: PostImage?
    /// Added to a past day: gets a paperclip instead of a pushpin.
    var isClipped = false
    /// Shown when you tap the paperclip, e.g. "Tues 3 at 9:14 PM". Only set for clipped posts.
    var addedLabel: String?
    /// When it was posted, to the minute: "Nov 13, 2026 at 11:58 PM" on an opened photo.
    var postedAt = Date()

    /// Rough height on the board, used to decide when a day gets busy. Close enough beats measuring.
    var estimatedHeight: CGFloat {
        switch kind {
        case .photo(let c): (PhotoMetrics.pinWidth / (image?.pinAspect ?? 1)) + 26 + (c.count > PhotoMetrics.captionCharsPerLine ? 13 : 0)   // picture plus the caption slip (one or two lines)
        case .sticky: 160
        case .journal: 160
        }
    }
}

extension Date {
    /// "Nov 13, 2026 at 11:58 PM": how a post's time reads on the Friends tab and on an opened photo.
    var postStamp: String { Self.stampFormatter.string(from: self) }
    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return f
    }()

    /// A moment on a day of the month the board is showing.
    static func onDay(_ day: Int, _ hour: Int, _ minute: Int) -> Date { BoardCalendar.date(day: day, hour: hour, minute: minute) }
}

struct IntoEntry: Identifiable, Hashable {
    let id = UUID()
    var month: String
    var text: String
}

struct BoardDay: Identifiable {
    let id: Int                   // day of month
    var posts: [Post]
}

@Observable
final class BoardStore {
    /// The board shows the real current month, and "today" is today (see `BoardCalendar`).
    var todayID: Int { BoardCalendar.today }

    var days: [BoardDay] = [
        BoardDay(id: 2, posts: [
            Post(kind: .photo(caption: "Rained all day"), rotation: -2.41, image: SamplePhotos.image(1), postedAt: .onDay(2, 9, 14)),
            Post(kind: .photo(caption: "this is a picture"), rotation: 2.6, image: SamplePhotos.image(0), postedAt: .onDay(2, 11, 58)),
            Post(kind: .sticky(text: "Watching this ever-so exciting movie that is about a group of elderly people who get together on Thursdays"), rotation: -1.2, postedAt: .onDay(2, 13, 20)),
            Post(kind: .journal(title: "short rant", body: "Watching this ever-so exciting movie that is about a group of elderly people who get together on Thursdays to solve cold murder cases."), rotation: 2.2, postedAt: .onDay(2, 15, 5)),
            Post(kind: .journal(title: "short rant", body: "Watching this ever-so exciting movie that is about a group of elderly people who get together on Thursdays to solve cold murder cases."), rotation: -2.0, postedAt: .onDay(2, 18, 40)),
            Post(kind: .journal(title: "short rant", body: "Watching this ever-so exciting movie that is about a group of elderly people who get together on Thursdays to solve cold murder cases."), rotation: 1.4, postedAt: .onDay(2, 21, 12)),
        ]),
        BoardDay(id: 3, posts: [])
    ]

    var currentlyInto = "pumpkin space lattes but not from starbucks"
    /// What you were into in earlier months, newest first. This is a journal: it is kept so you can look back.
    var intoHistory: [IntoEntry] = [
        IntoEntry(month: "October", text: "matcha and cozy games"),
        IntoEntry(month: "September", text: "running in the morning"),
        IntoEntry(month: "August", text: "film cameras"),
    ]
    /// Earlier values from this month, before you changed it. Newest first.
    var intoEarlierThisMonth: [String] = []
    var monthName: String { BoardCalendar.monthName }
    /// "Nov": for the day labels.
    var monthShort: String { BoardCalendar.monthShort }
    /// The month posts are saved under, like "2026-12".
    var monthKey: String { BoardCalendar.monthKey }

    /// Where posts are saved. Nil until someone is signed in, and posts just stay on the phone.
    @ObservationIgnored private var service: PostService?
    @ObservationIgnored private var uid: String?
    /// Finished months (as "2026-10") that have not been sealed yet, oldest first. Each gets the naming screen.
    var pendingSeals: [String] = []
    /// The month whose posts are on the board now, to notice when a new month begins.
    @ObservationIgnored private var loadedMonth = BoardCalendar.monthKey

    /// This month's question, the same for everyone (see `PromptCalendar`).
    var prompt = PromptCalendar.text(for: BoardCalendar.now)

    /// Swaps in the server's version of this month's prompt, if one was set there.
    func refreshPrompt() async {
        if let remote = await PromptCalendar.remoteText() { prompt = remote }
    }

    /// The composer sheet. Opened by the inline "Whats on your mind" button and by the prompt.
    var isComposing = false

    /// Set when the user taps the prompt card's "+": the next post answers it.
    var answeringPrompt = false
    var promptAnswerID: Post.ID?
    /// Ask the board to scroll to a post and give it a soft pulse (tapping the answered prompt card).
    var highlightRequest: Post.ID?
    /// The post that is pulsing right now.
    var highlightedPostID: Post.ID?

    /// Days you have folded away by tapping their date. Everything else shows all of its posts.
    var collapsedDays: Set<Int> = []

    // What the user is doing with an existing post (tap to open, long-press for the menu)
    var openedPostID: Post.ID?            // sticky or photo opened as a card in place
    var openedFrame: CGRect = .zero       // where it was on screen, so the card grows from there
    var openedJournalID: Post.ID?         // folded notes open as a full page
    var editRequest: Post.ID?
    var deleteRequest: Post.ID?

    var postCount = 0             // drives haptics
    var lastPostedDayID: Int?     // where the board scrolls to after posting

    // MARK: labels

    func shortLabel(_ id: Int) -> String { "\(BoardCalendar.weekday(of: id)) \(id)" }       // "Mon 2"
    func fullLabel(_ id: Int) -> String { "\(BoardCalendar.weekday(of: id)) \(BoardCalendar.monthNumber)/\(id)" }     // "Mon 11/2"

    /// Days you can post to: this month, up to today. Newest first.
    var postableDays: [Int] { Array((1...todayID).reversed()) }

    // MARK: the server

    /// Starts saving to the server for this person, and brings their board down: this month's posts, what they are
    /// into, their earlier "into"s, and which finished months still need sealing. Returns every month's record, so
    /// the shelf can load the sealed ones.
    @MainActor
    @discardableResult
    func connect(uid: String, service: PostService) async -> [BoardRecord] {
        self.uid = uid
        self.service = service
        let month = monthKey
        async let daysResult = try? service.loadDays(uid: uid, month: month)
        async let boardsResult = try? service.loadBoards(uid: uid)
        guard let loaded = await daysResult else { return [] }
        let records = await boardsResult ?? []
        loadedMonth = month

        var loadedDays = loaded
        if !loadedDays.contains(where: { $0.id == todayID }) {
            let at = loadedDays.firstIndex(where: { $0.id > todayID }) ?? loadedDays.endIndex
            loadedDays.insert(BoardDay(id: todayID, posts: []), at: at)
        }
        days = loadedDays
        promptAnswerID = days.lazy.flatMap(\.posts).first(where: \.isPromptAnswer)?.id

        // what they are into
        if let current = records.first(where: { $0.month == month }) {
            currentlyInto = current.into
            intoEarlierThisMonth = current.intoEarlier
        } else {
            currentlyInto = ""
            intoEarlierThisMonth = []
            if loaded.contains(where: { !$0.posts.isEmpty }) { await service.ensureBoard(uid: uid, month: month) }
        }
        intoHistory = records
            .filter { $0.month < month && !$0.into.isEmpty }
            .sorted { $0.month > $1.month }
            .map { IntoEntry(month: BoardCalendar.monthName(forKey: $0.month), text: $0.into) }

        // finished months that haven't been sealed
        pendingSeals = records.filter { !$0.sealed && $0.month < month }.map(\.month).sorted()

        await fetchThumbnails()
        return records
    }

    /// Called when the app comes back to the front: if the day has changed there is a new "today" row, and if the
    /// month has changed the board moves to the new month's posts.
    @MainActor
    func dayMayHaveChanged() async {
        if let uid, let service, loadedMonth != monthKey {
            await connect(uid: uid, service: service)
            return
        }
        if !days.contains(where: { $0.id == todayID }) {
            let at = days.firstIndex(where: { $0.id > todayID }) ?? days.endIndex
            days.insert(BoardDay(id: todayID, posts: []), at: at)
        }
    }

    /// Stops saving (signed out).
    func disconnect() { service = nil; uid = nil; pendingSeals = [] }

    /// Downloads the thumbnails of the pictures that are on the server but not here yet, a few at a time.
    /// (Thumbnails are small, and kept on the phone once fetched. Full pictures wait until a post is opened.)
    @MainActor
    private func fetchThumbnails() async {
        let wanted: [(Post.ID, StoredMedia)] = days.flatMap(\.posts).compactMap { p in
            guard let r = p.image?.remote, p.image?.hasThumbnail == false else { return nil }
            return (p.id, r)
        }
        await withTaskGroup(of: (Post.ID, UIImage?).self) { group in
            var iterator = wanted.makeIterator()
            func next() { if let (id, r) = iterator.next() { group.addTask { (id, (try? await MediaCache.shared.data(path: r.thumbPath)).flatMap(UIImage.init(data:))) } } }
            for _ in 0..<4 { next() }
            for await (id, image) in group {
                if let image { setThumbnail(id, image) }
                next()
            }
        }
    }

    private func setThumbnail(_ id: Post.ID, _ image: UIImage) {
        guard let d = dayID(of: id), let i = days.firstIndex(where: { $0.id == d }),
              let p = days[i].posts.firstIndex(where: { $0.id == id }), let remote = days[i].posts[p].image?.remote else { return }
        days[i].posts[p].image = PostImage(remote: remote, thumbnail: image)
    }

    /// Remembers where a post's picture went, once it has been uploaded.
    private func attach(_ stored: StoredMedia, to id: Post.ID) {
        guard let d = dayID(of: id), let i = days.firstIndex(where: { $0.id == d }),
              let p = days[i].posts.firstIndex(where: { $0.id == id }) else { return }
        days[i].posts[p].image?.remote = stored
    }

    /// Saves a new post.
    private func saveNew(_ id: Post.ID) {
        guard let service, let uid, let day = dayID(of: id), let i = days.firstIndex(where: { $0.id == day }),
              let order = days[i].posts.firstIndex(where: { $0.id == id }) else { return }
        let post = days[i].posts[order], month = monthKey
        Task {
            do {
                if let stored = try await service.create(post, uid: uid, month: month, day: day, order: order) { attach(stored, to: id) }
            } catch {
                NSLog("Couldn't save a post: %@", error.localizedDescription)
            }
        }
    }

    /// Saves some changed fields of a post.
    private func saveChange(_ id: Post.ID, _ fields: [String: Any]) {
        guard let service else { return }
        Task { do { try await service.update(id, fields: fields) } catch { NSLog("Couldn't save a change: %@", error.localizedDescription) } }
    }

    // MARK: a new person's board

    /// What someone sees right after signing up: today, with nothing on it, and nothing set yet. The sample
    /// days above are only for the designs.
    func startFresh() {
        days = [BoardDay(id: todayID, posts: [])]
        currentlyInto = ""
        intoHistory = []
        intoEarlierThisMonth = []
        promptAnswerID = nil
        collapsedDays = []
    }

    // MARK: currently into

    /// Changing it mid-month is fine; the old value is kept under this month's history.
    func setInto(_ text: String) {
        let new = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty, new != currentlyInto else { return }
        intoEarlierThisMonth.removeAll { $0 == new || $0 == currentlyInto }
        if !currentlyInto.isEmpty { intoEarlierThisMonth.insert(currentlyInto, at: 0) }
        currentlyInto = new
        if let service, let uid {
            let month = monthKey, into = new, earlier = intoEarlierThisMonth
            Task { try? await service.saveInto(uid: uid, month: month, into: into, earlier: earlier) }
        }
    }

    // MARK: the prompt

    /// Only one post answers the prompt. Using an older post tags it; it stays on its own day.
    func answerPrompt(with id: Post.ID) {
        guard post(id) != nil else { return }
        setPromptAnswer(nil)
        setPromptAnswer(id)
        highlightRequest = id
    }

    /// The post stays on the board; it just stops being the prompt's answer.
    func removePromptAnswer() { setPromptAnswer(nil) }

    private func setPromptAnswer(_ id: Post.ID?) {
        for d in days.indices {
            for p in days[d].posts.indices {
                let isIt = days[d].posts[p].id == id
                if isIt || days[d].posts[p].id == promptAnswerID {
                    days[d].posts[p].isPromptAnswer = isIt
                    saveChange(days[d].posts[p].id, ["isPromptAnswer": isIt])
                }
            }
        }
        promptAnswerID = id
    }

    // MARK: existing posts

    func post(_ id: Post.ID) -> Post? { days.lazy.flatMap(\.posts).first { $0.id == id } }

    func dayID(of id: Post.ID) -> Int? { days.first { $0.posts.contains { $0.id == id } }?.id }

    func delete(_ id: Post.ID) {
        guard let d = days.firstIndex(where: { $0.posts.contains { $0.id == id } }) else { return }
        let media = days[d].posts.first { $0.id == id }?.image?.remote
        days[d].posts.removeAll { $0.id == id }
        if let service { Task { try? await service.delete(id, media: media) } }
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
        if let service {
            let order = days[d].posts.map(\.id)
            Task { try? await service.reorder(order) }
        }
        return true
    }

    /// Edit in place: no "edited" marker, as in the rules.
    func update(_ id: Post.ID, title: String, body: String, asJournal: Bool, stickyColor: StickyColor = .yellow) {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let d = dayID(of: id),
              let i = days.firstIndex(where: { $0.id == d }),
              let p = days[i].posts.firstIndex(where: { $0.id == id }) else { return }
        days[i].posts[p].kind = asJournal
            ? .journal(title: title.trimmingCharacters(in: .whitespacesAndNewlines), body: text)
            : .sticky(text: text)
        if !asJournal { days[i].posts[p].stickyColor = stickyColor }
        saveChange(id, PostService.textFields(for: days[i].posts[p]))
        postCount += 1
    }

    func updateCaption(_ id: Post.ID, caption: String) {
        guard let d = dayID(of: id),
              let i = days.firstIndex(where: { $0.id == d }),
              let p = days[i].posts.firstIndex(where: { $0.id == id }) else { return }
        days[i].posts[p].kind = .photo(caption: String(caption.trimmingCharacters(in: .whitespacesAndNewlines).prefix(PhotoMetrics.captionLimit)))
        saveChange(id, PostService.textFields(for: days[i].posts[p]))
    }

    /// Fold a day away, or open it back up.
    func toggleDay(_ dayID: Int) {
        if collapsedDays.contains(dayID) { collapsedDays.remove(dayID) } else { collapsedDays.insert(dayID) }
    }

    /// Make sure a day is open (a new post lands in it, or something is about to scroll to it).
    func openDay(_ dayID: Int) { collapsedDays.remove(dayID) }

    // MARK: posting

    /// A post is a sticky, a journal entry, or (with `photo`) a photo whose text is its caption.
    func addPost(title: String, body: String, dayID: Int, asJournal: Bool, photo: PostImage? = nil, stickyColor: StickyColor = .yellow) {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!text.isEmpty || photo != nil), (1...todayID).contains(dayID) else { return }

        var post = Post(
            kind: photo != nil
                ? .photo(caption: text)
                : asJournal
                    ? .journal(title: title.trimmingCharacters(in: .whitespacesAndNewlines), body: text)
                    : .sticky(text: text),
            rotation: .random(in: -3...3)
        )
        post.image = photo
        post.stickyColor = stickyColor
        // the time of day is now's
        let clock = Calendar.current.dateComponents([.hour, .minute], from: .now)
        post.postedAt = .onDay(dayID, clock.hour ?? 12, clock.minute ?? 0)
        post.isClipped = dayID != todayID
        if post.isClipped {
            let time = Date.now.formatted(date: .omitted, time: .shortened)
            post.addedLabel = "\(shortLabel(todayID)) at \(time)"
        }
        if answeringPrompt {
            setPromptAnswer(nil)          // one answer only: a new one replaces any older one
            post.isPromptAnswer = true
            promptAnswerID = post.id
        }

        if let i = days.firstIndex(where: { $0.id == dayID }) {
            days[i].posts.append(post)
        } else {
            // a day with no row yet: add it in order
            let at = days.firstIndex(where: { $0.id > dayID }) ?? days.endIndex
            days.insert(BoardDay(id: dayID, posts: [post]), at: at)
        }
        openDay(dayID)
        lastPostedDayID = dayID
        postCount += 1
        saveNew(post.id)
    }
}
