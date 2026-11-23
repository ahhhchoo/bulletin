import UIKit
import FirebaseFirestore

/// One month's board record: what you were into, and (once the month is sealed) its title, cover and numbers.
struct BoardRecord {
    var month: String                 // "2026-11"
    var into = ""
    var intoEarlier: [String] = []
    var sealed = false
    var title = ""
    var cover: StoredMedia?
    var pins = 0
    var notes = 0
    var busiest = 0
}

/// Saves and loads a person's posts in Firestore (`posts/{id}`), and sends their pictures to Storage.
///
/// A post is one document: who owns it, which month and day, its text, and where its pictures are. The pictures are
/// not in the document; it holds their paths and sizes so a feed can lay itself out and then fetch only what it shows.
/// The rules are in `backend/firestore.rules`.
@Observable
final class PostService {
    private var db: Firestore { Firestore.firestore() }
    private let media: MediaStore = FirebaseMediaStore()
    /// Months whose board record is known to exist, so it isn't rewritten with every post. Several loads can run at
    /// once, so the set is only touched behind a lock.
    @ObservationIgnored private let ensuredLock = NSLock()
    @ObservationIgnored private var ensuredBoards = Set<String>()
    private func isEnsured(_ month: String) -> Bool { ensuredLock.withLock { ensuredBoards.contains(month) } }
    private func markEnsured(_ month: String) { ensuredLock.withLock { _ = ensuredBoards.insert(month) } }

    // MARK: saving

    /// Uploads the post's picture (if it has one that isn't up yet) and writes the post. Returns where the picture
    /// went, so the post can remember it.
    @discardableResult
    func create(_ post: Post, uid: String, month: String, day: Int, order: Int) async throws -> StoredMedia? {
        var stored = post.image?.remote
        if stored == nil, let processed = post.image?.media {
            stored = try await media.upload(processed, userID: uid)
        }
        var data = Self.fields(for: post)
        data["ownerId"] = uid
        data["month"] = month
        data["day"] = day
        data["order"] = order
        data["createdAt"] = FieldValue.serverTimestamp()
        if let stored { data["media"] = Self.dictionary(stored) }
        let batch = db.batch()
        batch.setData(data, forDocument: db.collection("posts").document(post.id.uuidString))
        // the month's board record exists as soon as it has a post, so the month can be found and sealed later
        if !isEnsured(month) {
            batch.setData(["ownerId": uid, "month": month, "sealed": false], forDocument: boardRef(uid, month), merge: true)
        }
        try await batch.commit()
        markEnsured(month)
        return stored
    }

    /// Changes some fields of a post (its text, its prompt tag, its place in the day).
    func update(_ id: Post.ID, fields: [String: Any]) async throws {
        try await db.collection("posts").document(id.uuidString).updateData(fields)
    }

    /// Writes the order of a day's posts in one go.
    func reorder(_ ids: [Post.ID]) async throws {
        let batch = db.batch()
        for (i, id) in ids.enumerated() {
            batch.updateData(["order": i], forDocument: db.collection("posts").document(id.uuidString))
        }
        try await batch.commit()
    }

    /// Deletes the post and its pictures.
    func delete(_ id: Post.ID, media stored: StoredMedia?) async throws {
        try await db.collection("posts").document(id.uuidString).delete()
        if let stored { await FirebaseMediaStore.delete(stored) }
    }

    // MARK: loading

    /// A month's posts, grouped by day, in the order they were arranged. Pictures come back as blanks of the right
    /// shape: the board fetches the thumbnails afterwards.
    func loadDays(uid: String, month: String) async throws -> [BoardDay] {
        let snap = try await db.collection("posts")
            .whereField("ownerId", isEqualTo: uid)
            .whereField("month", isEqualTo: month)
            .getDocuments()

        var byDay: [Int: [(order: Int, post: Post)]] = [:]
        for doc in snap.documents {
            guard let post = Self.post(from: doc) else { continue }
            let day = doc.data()["day"] as? Int ?? 1
            byDay[day, default: []].append((doc.data()["order"] as? Int ?? 0, post))
        }
        return byDay.keys.sorted().map { day in
            BoardDay(id: day, posts: byDay[day]!.sorted { ($0.order, $0.post.postedAt) < ($1.order, $1.post.postedAt) }.map(\.post))
        }
    }

    // MARK: month boards

    private func boardRef(_ uid: String, _ month: String) -> DocumentReference {
        db.collection("boards").document("\(uid)_\(month)")
    }

    /// Every month's board record for this person.
    func loadBoards(uid: String) async throws -> [BoardRecord] {
        let snap = try await db.collection("boards").whereField("ownerId", isEqualTo: uid).getDocuments()
        for doc in snap.documents { if let m = doc.data()["month"] as? String { markEnsured(m) } }
        return snap.documents.compactMap { doc in
            let d = doc.data()
            guard let month = d["month"] as? String else { return nil }
            return BoardRecord(month: month, into: d["into"] as? String ?? "", intoEarlier: d["intoEarlier"] as? [String] ?? [],
                               sealed: d["sealed"] as? Bool ?? false, title: d["title"] as? String ?? "",
                               cover: (d["cover"] as? [String: Any]).flatMap(Self.storedMedia),
                               pins: d["pins"] as? Int ?? 0, notes: d["notes"] as? Int ?? 0, busiest: d["busiest"] as? Int ?? 0)
        }
    }

    /// Makes sure this month's record exists (for months whose posts were saved before records existed).
    func ensureBoard(uid: String, month: String) async {
        guard !isEnsured(month) else { return }
        try? await boardRef(uid, month).setData(["ownerId": uid, "month": month, "sealed": false], merge: true)
        markEnsured(month)
    }

    /// Saves what you are into this month, and the values it had earlier in the month.
    func saveInto(uid: String, month: String, into: String, earlier: [String]) async throws {
        try await boardRef(uid, month).setData(["ownerId": uid, "month": month, "sealed": false,
                                                 "into": into, "intoEarlier": Array(earlier.prefix(20))], merge: true)
        markEnsured(month)
    }

    /// Seals a month. After this the server refuses new posts and edits to it (deleting is still allowed).
    func sealMonth(uid: String, month: String, title: String, cover: StoredMedia?, pins: Int, notes: Int, busiest: Int) async throws {
        var data: [String: Any] = ["ownerId": uid, "month": month, "sealed": true, "sealedAt": FieldValue.serverTimestamp(),
                                   "title": title, "pins": pins, "notes": notes, "busiest": busiest]
        if let cover { data["cover"] = Self.dictionary(cover) }
        try await boardRef(uid, month).setData(data, merge: true)
        markEnsured(month)
    }

    /// Renames a sealed month and/or changes its cover.
    func updateMonth(uid: String, month: String, title: String, cover: StoredMedia?) async throws {
        try await boardRef(uid, month).updateData([
            "title": title,
            "cover": cover.map { Self.dictionary($0) } ?? FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    /// Fills in the thumbnails of every picture in these days (a few downloads at a time).
    func withThumbnails(_ days: [BoardDay]) async -> [BoardDay] {
        var days = days
        let wanted: [(Post.ID, StoredMedia)] = days.flatMap(\.posts).compactMap { p in
            guard let r = p.image?.remote, p.image?.hasThumbnail == false else { return nil }
            return (p.id, r)
        }
        var found: [Post.ID: UIImage] = [:]
        await withTaskGroup(of: (Post.ID, UIImage?).self) { group in
            var iterator = wanted.makeIterator()
            func next() { if let (id, r) = iterator.next() { group.addTask { (id, (try? await MediaCache.shared.data(path: r.thumbPath)).flatMap(UIImage.init(data:))) } } }
            for _ in 0..<4 { next() }
            for await (id, image) in group { if let image { found[id] = image }; next() }
        }
        for d in days.indices {
            for p in days[d].posts.indices {
                if let image = found[days[d].posts[p].id], let remote = days[d].posts[p].image?.remote {
                    days[d].posts[p].image = PostImage(remote: remote, thumbnail: image)
                }
            }
        }
        return days
    }

    // MARK: documents <-> posts

    /// The fields that describe the post itself (not who owns it or where it sits).
    static func fields(for post: Post) -> [String: Any] {
        var d: [String: Any] = [
            "rotation": post.rotation,
            "isPromptAnswer": post.isPromptAnswer,
            "isClipped": post.isClipped,
            "postedAt": Timestamp(date: post.postedAt),
            "stickyColor": post.stickyColor.rawValue,
        ]
        if let label = post.addedLabel { d["addedLabel"] = label }
        switch post.kind {
        case .photo(let caption): d["kind"] = "photo"; d["text"] = caption
        case .sticky(let text): d["kind"] = "sticky"; d["text"] = text
        case .journal(let title, let body): d["kind"] = "journal"; d["text"] = body; d["title"] = title
        }
        return d
    }

    /// Just the text fields, for an edit.
    static func textFields(for post: Post) -> [String: Any] {
        let all = fields(for: post)
        return all.filter { ["kind", "text", "title", "stickyColor"].contains($0.key) }
    }

    static func dictionary(_ m: StoredMedia) -> [String: Any] {
        var d: [String: Any] = ["fullPath": m.fullPath, "thumbPath": m.thumbPath, "width": m.width, "height": m.height, "isAnimated": m.isAnimated]
        if let feed = m.feedPath { d["feedPath"] = feed }
        return d
    }

    private static func post(from doc: QueryDocumentSnapshot) -> Post? {
        let d = doc.data()
        guard let id = UUID(uuidString: doc.documentID), let kind = d["kind"] as? String else { return nil }
        let text = d["text"] as? String ?? ""
        var post = Post(kind: .sticky(text: text), rotation: (d["rotation"] as? Double) ?? 0)
        post.id = id
        switch kind {
        case "photo": post.kind = .photo(caption: text)
        case "journal": post.kind = .journal(title: d["title"] as? String ?? "", body: text)
        default: post.kind = .sticky(text: text)
        }
        post.stickyColor = StickyColor(rawValue: d["stickyColor"] as? String ?? "") ?? .yellow
        post.isPromptAnswer = d["isPromptAnswer"] as? Bool ?? false
        post.isClipped = d["isClipped"] as? Bool ?? false
        post.addedLabel = d["addedLabel"] as? String
        post.postedAt = (d["postedAt"] as? Timestamp)?.dateValue() ?? .now
        if let m = d["media"] as? [String: Any], let stored = storedMedia(m) { post.image = PostImage(remote: stored) }
        return post
    }

    static func storedMedia(_ m: [String: Any]) -> StoredMedia? {
        guard let full = m["fullPath"] as? String, let thumb = m["thumbPath"] as? String else { return nil }
        return StoredMedia(fullPath: full, thumbPath: thumb, feedPath: m["feedPath"] as? String,
                           width: m["width"] as? Int ?? 1, height: m["height"] as? Int ?? 1,
                           isAnimated: m["isAnimated"] as? Bool ?? false)
    }
}
