import SwiftUI

/// The sealed months on your shelf, newest first. Each keeps its own title, its cover photo and the days it was
/// sealed with, so opening it shows the board as it was.
///
/// Sealed months live on the server (`boards/{uid}_{month}`). The shelf loads their covers; a month's posts are only
/// loaded when you open it.
@Observable
final class ShelfStore {
    var months: [ShelfMonth] = ShelfMonth.all

    @ObservationIgnored private var service: PostService?
    @ObservationIgnored private var uid: String?

    /// A new account has no sealed months. (The made-up ones are only for the designs.)
    func startFresh() { months = [] }

    func month(_ id: ShelfMonth.ID) -> ShelfMonth? { months.first { $0.id == id } }

    // MARK: the server

    /// Shows this person's sealed months (empty months are left off), and starts saving changes to them.
    @MainActor
    func load(_ records: [BoardRecord], uid: String, service: PostService) async {
        self.uid = uid
        self.service = service
        months = records.filter { $0.sealed && $0.pins > 0 }.sorted { $0.month > $1.month }.map(Self.shelfMonth)
        await fetchCovers()
    }

    private static func shelfMonth(_ r: BoardRecord) -> ShelfMonth {
        let date = BoardCalendar.date(forKey: r.month)
        var m = ShelfMonth(short: BoardCalendar.format("MMM", date), year: BoardCalendar.format("yy", date), title: r.title, photo: -1,
                           full: BoardCalendar.format("MMMM", date), pins: r.pins, notes: r.notes, busiest: r.busiest)
        m.cover = r.cover.map { PostImage(remote: $0) }
        m.monthKey = r.month
        return m
    }

    /// Downloads the cover thumbnails.
    @MainActor
    private func fetchCovers() async {
        for i in months.indices {
            guard let remote = months[i].cover?.remote, months[i].cover?.hasThumbnail == false,
                  let data = try? await MediaCache.shared.data(path: remote.thumbPath), let image = UIImage(data: data),
                  months.indices.contains(i), months[i].cover?.remote == remote else { continue }
            months[i].cover = PostImage(remote: remote, thumbnail: image)
        }
    }

    /// Brings a sealed month's posts down (once), so it can be opened or renamed with its photos.
    @MainActor
    func ensureDays(_ id: ShelfMonth.ID) async {
        guard let i = months.firstIndex(where: { $0.id == id }), months[i].days.isEmpty,
              let key = months[i].monthKey, let uid, let service,
              let loaded = try? await service.loadDays(uid: uid, month: key) else { return }
        let withPictures = await service.withThumbnails(loaded)
        if let j = months.firstIndex(where: { $0.id == id }) { months[j].days = withPictures }
    }

    // MARK: changing

    /// Renames a month and sets its cover photo. An empty title is allowed: the month is just its name.
    func update(_ id: ShelfMonth.ID, title: String, cover: PostImage?) {
        guard let i = months.firstIndex(where: { $0.id == id }) else { return }
        let clean = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        months[i].title = clean
        months[i].cover = cover
        if let service, let uid, let key = months[i].monthKey {
            let media = cover?.remote
            Task { try? await service.updateMonth(uid: uid, month: key, title: clean, cover: media) }
        }
    }

    /// Seals a finished month: names it, picks its cover and puts it on the shelf. The server then refuses new posts
    /// and edits to that month. A month with nothing in it is sealed but not shelved.
    @MainActor
    func seal(monthKey: String, days: [BoardDay], title: String, cover: PostImage?, notes: (Post.ID) -> Int,
              service: PostService?, uid: String?) async {
        let posts = days.flatMap(\.posts)
        let clean = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        let chosen = cover ?? posts.compactMap(\.image).first
        let busiest = days.max { $0.posts.count < $1.posts.count }?.id ?? 0
        let noteCount = posts.reduce(0) { $0 + notes($1.id) }

        if let service, let uid {
            try? await service.sealMonth(uid: uid, month: monthKey, title: clean, cover: chosen?.remote,
                                         pins: posts.count, notes: noteCount, busiest: busiest)
        }
        guard !posts.isEmpty else { return }

        let date = BoardCalendar.date(forKey: monthKey)
        var month = ShelfMonth(short: BoardCalendar.format("MMM", date), year: BoardCalendar.format("yy", date), title: clean,
                               photo: -1, full: BoardCalendar.format("MMMM", date), pins: posts.count, notes: noteCount,
                               busiest: busiest, days: days, cover: chosen)
        month.monthKey = monthKey
        months.removeAll { $0.monthKey == monthKey }
        months.append(month)
        months.sort { ($0.monthKey ?? "") > ($1.monthKey ?? "") }
    }
}
