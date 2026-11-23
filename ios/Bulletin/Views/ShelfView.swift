import SwiftUI
import UIKit

/// One sealed month on the shelf.
struct ShelfMonth: Identifiable {
    let id = UUID()
    let short: String
    let year: String
    var title: String
    /// Which sample photo leads the card (-1: none). Only the seeded months use this; a chosen `cover` wins.
    let photo: Int
    var full = ""
    var pins = 0
    var notes = 0
    var busiest = 0
    /// The board as it was when the month was sealed.
    var days: [BoardDay] = []
    /// The photo picked from that month to lead its card.
    var cover: PostImage?
    /// "2026-10": which month this is on the server. Nil for the made-up months in the designs.
    var monthKey: String?

    var image: UIImage? {
        cover?.uiImage ?? (photo >= 0 ? SamplePhotos.image(photo)?.uiImage : nil)
    }
    /// Every picture posted that month: what a cover can be picked from.
    var photos: [PostImage] { days.flatMap(\.posts).compactMap(\.image) }
    var palette: AmbientPalette? { palette(softness: AmbientPalette.softness) }

    func palette(softness: Double) -> AmbientPalette? {
        image.map { AmbientPalette.of($0, key: cover.map { $0.id.hashValue } ?? photo, softness: softness) }
    }

    private static let seeds: [ShelfMonth] = [
        .init(short: "Oct", year: "26", title: "The month of Yzma", photo: 0, full: "October", pins: 24, notes: 31, busiest: 14),
        .init(short: "Sep", year: "26", title: "Back to school", photo: 1, full: "September", pins: 17, notes: 12, busiest: 3),
        .init(short: "Aug", year: "26", title: "Beach, mostly", photo: 2, full: "August", pins: 31, notes: 22, busiest: 21),
        .init(short: "Jul", year: "26", title: "No plans", photo: 3, full: "July", pins: 9, notes: 5, busiest: 4),
        .init(short: "Jun", year: "26", title: "Moved apartments", photo: 1, full: "June", pins: 28, notes: 19, busiest: 12),
        .init(short: "May", year: "26", title: "Slow mornings", photo: 3, full: "May", pins: 12, notes: 7, busiest: 5),
        .init(short: "Apr", year: "26", title: "Tulips", photo: 2, full: "April", pins: 14, notes: 8, busiest: 9),
        .init(short: "Mar", year: "26", title: "The long rain", photo: 0, full: "March", pins: 21, notes: 15, busiest: 18),
    ]

    /// The seeded months get a few made-up days so opening one has something to show (until real months are sealed).
    static let all: [ShelfMonth] = seeds.map { m in
        var m = m
        m.days = [
            BoardDay(id: 3, posts: [
                Post(kind: .sticky(text: "first week of \(m.full.lowercased()), already tired"), rotation: -1.4),
                Post(kind: .photo(caption: "outside"), rotation: 2, image: SamplePhotos.image(m.photo)),
            ]),
            BoardDay(id: 9, posts: [
                Post(kind: .journal(title: "short rant", body: "Watching this ever-so exciting movie that is about a group of elderly people who get together on Thursdays to solve cold murder cases."), rotation: 1.8),
            ]),
            BoardDay(id: 14, posts: [
                Post(kind: .photo(caption: "this one"), rotation: -2.2, image: SamplePhotos.image(m.photo + 1)),
                Post(kind: .photo(caption: "and this"), rotation: 1.6, image: SamplePhotos.image(m.photo + 2)),
            ]),
        ]
        return m
    }
}


/// Two colors lifted from a photo, light and dark, so the card feels like it belongs to the picture.
/// (Sampled the same way as the prototype: shrink to 6×6, average a few regions, nudge the saturation,
/// then wash toward white by `softness` so it never gets loud.)
struct AmbientPalette {
    let light: Color
    let mid: Color
    let dark: Color
    /// Dark text on this card, or white.
    let darkText: Bool

    static let softness = 0.45
    /// The sheet is washed further toward the paper so the tape on the photo blends into it.
    static let sheetSoftness = 0.6
    private static var cache: [Int: AmbientPalette] = [:]

    static func of(_ image: UIImage, key: Int, softness: Double = softness) -> AmbientPalette {
        let id = key &* 1000 &+ Int((softness * 100).rounded())
        if let hit = cache[id] { return hit }
        let p = sample(image, softness: softness)
        cache[id] = p
        return p
    }

    private static func sample(_ image: UIImage, softness: Double) -> AmbientPalette {
        let n = 6
        var px = [UInt8](repeating: 0, count: n * n * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8,
                                      bytesPerRow: n * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let cg = image.cgImage else { return }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        }
        func avg(_ i0: Int, _ i1: Int, _ j0: Int, _ j1: Int) -> [Double] {
            var s = [0.0, 0.0, 0.0], c = 0.0
            for j in j0..<j1 { for i in i0..<i1 {
                let k = (j * n + i) * 4
                s[0] += Double(px[k]); s[1] += Double(px[k + 1]); s[2] += Double(px[k + 2]); c += 1
            } }
            return s.map { $0 / c }
        }
        func boost(_ c: [Double], _ k: Double) -> [Double] {
            let m = (c[0] + c[1] + c[2]) / 3
            return c.map { u in
                let v = min(255, max(0, m + (u - m) * 1.25))
                return v + (255 - v) * k
            }
        }
        func color(_ c: [Double]) -> Color { Color(red: c[0] / 255, green: c[1] / 255, blue: c[2] / 255) }

        let k = softness
        let all = avg(0, n, 0, n), mid = avg(1, 5, 1, 5), tl = avg(0, 3, 0, 3)
        let lo = boost(all, k * 0.55), hi = boost(mid, min(0.9, k + 0.18)), base = boost(tl, k)
        let wash = boost(all, k)
        let lum = (0.299 * wash[0] + 0.587 * wash[1] + 0.114 * wash[2]) / 255
        return AmbientPalette(light: color(hi), mid: color(base), dark: color(lo), darkText: lum >= 0.5)
    }

    var gradient: LinearGradient {
        LinearGradient(stops: [.init(color: light, location: 0), .init(color: mid, location: 0.45),
                               .init(color: dark, location: 1)],
                       startPoint: UnitPoint(x: 0.1, y: 0), endPoint: UnitPoint(x: 0.9, y: 1))
    }
}

/// A month on the shelf: its title, the month in big type with the year ghosted, and a photo on the right.
/// 350×120, as in the Figma frame.
struct MonthCard: View {
    let month: ShelfMonth

    private static let corner: CGFloat = 24

    private var image: UIImage? { month.image }
    private var palette: AmbientPalette? { month.palette }
    private var text: Color { (palette?.darkText ?? true) ? .black : .white }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background

            Text(month.title)
                .font(Typo.pixel(12))
                .foregroundStyle(text.opacity(0.7))
                .lineLimit(1)
                .padding(.leading, 16).padding(.top, 16)

            HStack(spacing: 0) {
                Text(month.short).foregroundStyle(text)
                Text(month.year).foregroundStyle(text.opacity(0.14))
            }
            .font(.system(size: 56, weight: .bold))
            .tracking(-2)
            .lineLimit(1)
            .fixedSize()
            .padding(.leading, 12)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .offset(y: 2)

            if let image {
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: 123, height: 98)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 11)
            }
        }
        .frame(width: 350, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: Self.corner, style: .continuous))
        // "Blur + Shadow Big": a soft close shadow and a long faint one
        .shadow(color: .black.opacity(0.09), radius: 5, y: 7)
        .shadow(color: .black.opacity(0.18), radius: 28, y: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(month.short) \(month.year), \(month.title)")
    }

    @ViewBuilder private var background: some View {
        if let palette {
            Rectangle().fill(palette.gradient)
        } else {
            Rectangle().fill(Color(white: 0.86))
        }
    }
}

/// What opens when you tap a month: its own color, the lead photo tipped like it was just set down, the month in
/// big type, a few numbers, and what you can do with it.
struct MonthSheet: View {
    let month: ShelfMonth
    let close: () -> Void
    let onRename: () -> Void
    let onOpen: () -> Void
    @State private var settled = false

    private var palette: AmbientPalette? { month.palette(softness: AmbientPalette.sheetSoftness) }
    private var text: Color { (palette?.darkText ?? true) ? .black : .white }

    var body: some View {
        ZStack(alignment: .top) {
            if let palette { Rectangle().fill(palette.gradient).ignoresSafeArea() }
            else { Color(white: 0.86).ignoresSafeArea() }

            VStack(spacing: 0) {
                if let image = month.image {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 168, height: 168)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
                        .rotationEffect(.degrees(settled ? -8 : -14))
                        .scaleEffect(settled ? 1 : 0.8)
                }
                Text(month.full)
                    .font(.system(size: 46, weight: .heavy)).tracking(-1.6)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                // the title, as plain text: editing it is the "Edit" button below
                if !month.title.isEmpty {
                    Text(month.title.lowercased())
                        .font(Typo.pixel(13)).opacity(0.6).lineLimit(1)
                        .padding(.top, 14)
                }

                HStack(spacing: 26) {
                    stat(month.pins, "pinned"); stat(month.notes, "notes"); stat(month.busiest, "busiest day")
                }
                .padding(.top, 20)

                VStack(spacing: 10) {
                    action("Open \(month.full)’s Bulletin", main: true, perform: onOpen)
                    action("Edit name and photo", perform: onRename)
                }
                .padding(.top, 26)
                Spacer(minLength: 0)
            }
            .padding(.top, 110)
            .padding(.horizontal, 24)

            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.12), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 20).padding(.top, 60)
            .accessibilityLabel("Close")
        }
        .foregroundStyle(text)
        .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.4)) { settled = true } }
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(n)").font(Typo.pixel(26))
            Text(label).font(.system(size: 11, weight: .medium)).opacity(0.6)
        }
    }

    private func action(_ title: String, main: Bool = false, perform: @escaping () -> Void = {}) -> some View {
        Button(action: perform) {
            Text(title).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(main ? .white : text)
                .frame(width: 280)
                .padding(.vertical, 15)
                .background(main ? Color.black : Color.white.opacity(0.4), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// What the shelf shows before any month has ended: a few blank covers waiting, with this month in front, still open.
struct ShelfEmptyState: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    private static let monthFormat: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM"; return f }()
    private static let yearFormat: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yy"; return f }()
    private static let longFormat: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMMM"; return f }()
    private static let dayFormat: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d"; return f }()

    private var now: Date { BoardCalendar.now }
    /// The first of next month: when the open month seals.
    private var sealsOn: Date {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return cal.date(byAdding: .month, value: 1, to: start) ?? now
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 120)
            stack.frame(height: 260)
            Text("Nothing on your shelf yet.")
                .font(.system(size: 30, weight: .heavy)).tracking(-0.9)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Text("\(Self.longFormat.string(from: now)) is still open. When a month ends, it lands here as a cover you can name and flip back through.")
                .font(.system(size: 15))
                .foregroundStyle(.black.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.top, 10).padding(.horizontal, 12)
            Text("\(Self.longFormat.string(from: now)) seals \(Self.dayFormat.string(from: sealsOn))")
                .font(Typo.pixel(12))
                .foregroundStyle(.black.opacity(0.45))
                .padding(.top, 16)
            Spacer(minLength: 150)
        }
        .padding(.horizontal, 27)
        .frame(maxWidth: .infinity)
        .onAppear {
            if reduceMotion { landed = true } else { withAnimation(.spring(duration: 0.7, bounce: 0.3).delay(0.1)) { landed = true } }
        }
        .accessibilityElement(children: .combine)
    }

    /// Two empty covers behind, and this month in front. They fan out and settle like the shelf's cascade.
    private var stack: some View {
        ZStack {
            ghost.rotationEffect(.degrees(landed ? -7 : -2)).offset(x: landed ? -10 : 0, y: landed ? -74 : -20).opacity(0.55)
            ghost.rotationEffect(.degrees(landed ? 5 : 1)).offset(x: landed ? 12 : 0, y: landed ? -38 : -10).opacity(0.8)
            current.rotationEffect(.degrees(landed ? -1.5 : 0)).offset(y: landed ? 18 : 0)
        }
        .scaleEffect(0.9)
    }

    /// An empty cover: where a sealed month will sit.
    private var ghost: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.black.opacity(0.18), style: StrokeStyle(lineWidth: 1.4, dash: [6, 5])))
            .frame(width: 350, height: 120)
    }

    /// This month, as a cover that isn't finished yet.
    private var current: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white)
            Text("In progress")
                .font(Typo.pixel(12)).foregroundStyle(.black.opacity(0.6))
                .padding(.leading, 16).padding(.top, 16)
            HStack(spacing: 0) {
                Text(Self.monthFormat.string(from: now)).foregroundStyle(.black)
                Text(Self.yearFormat.string(from: now)).foregroundStyle(.black.opacity(0.14))
            }
            .font(.system(size: 56, weight: .bold)).tracking(-2)
            .lineLimit(1).fixedSize()
            .padding(.leading, 12)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .offset(y: 2)
            Text("open now")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(.black, in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(14)
        }
        .frame(width: 350, height: 120)
        .shadow(color: .black.opacity(0.09), radius: 5, y: 7)
        .shadow(color: .black.opacity(0.14), radius: 24, y: 16)
    }
}

/// The shelf: sealed months in a cascade. A card is straight near the middle of the screen and tilts, shrinks and
/// fades the further it sits from there, so the stack feels like it is being flipped through.
struct ShelfView: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(ShelfStore.self) private var shelf
    @State private var showSettings = false
    @State private var viewport: CGFloat = 874
    @State private var openedID: ShelfMonth.ID?
    @State private var renaming: ShelfMonth?
    @State private var reading: ShelfMonth?

    /// Sealed months, newest first.
    private var months: [ShelfMonth] { shelf.months }
    private var opened: ShelfMonth? { openedID.flatMap { shelf.month($0) } }

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(Array(months.enumerated()), id: \.element.id) { i, month in
                        let vh = viewport
                        MonthCard(month: month)
                            .onTapGesture { withAnimation(.spring(duration: 0.45, bounce: 0.2)) { openedID = month.id } }
                            .visualEffect { content, proxy in
                                let frame = proxy.frame(in: .scrollView)
                                let mid = vh * 0.46, half = vh * 0.42
                                let d = max(-1.4, min(1.4, (frame.midY - mid) / half))
                                let ad = abs(d)
                                let alt: CGFloat = i % 2 == 1 ? 1 : -1
                                let rot = d * 13 + alt * min(ad * 2, 1) * 3
                                return content
                                    .scaleEffect(1 - ad * 0.07)
                                    .rotationEffect(.degrees(rot))
                                    .offset(x: alt * ad * 10)
                                    .opacity(max(0.25, 1 - max(0, ad - 0.55) * 0.9))
                                    .blur(radius: ad > 0.95 ? (ad - 0.95) * 5 : 0)
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 110)
                .padding(.bottom, 230)
            }
            .scrollIndicators(.hidden)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: .clear, location: 96 / viewport),
                                       .init(color: .black, location: 150 / viewport)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }

            if months.isEmpty { ShelfEmptyState() }

            Text("Shelf")
                .font(.system(size: 26, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16).padding(.top, 57)     // same spot as "Shared" and "Prompts"
                .ignoresSafeArea(edges: .top)

            // your picture, top right: opens your profile settings
            if opened == nil {
                Button { showSettings = true } label: {
                    Group {
                        if profile.isSignedUp {
                            AvatarView(photo: profile.photo, initial: profile.initial, size: 36)
                                .shadow(color: .clear, radius: 0)
                        } else {
                            Image(systemName: "person.crop.circle").font(.system(size: 30)).foregroundStyle(.black)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16).padding(.top, 53)    // same spot as the guests icon on Shared
                .ignoresSafeArea(edges: .top)
                .accessibilityLabel("Profile and settings")
            }

            if let month = opened {
                MonthSheet(month: month,
                           close: { withAnimation(.spring(duration: 0.4, bounce: 0.1)) { openedID = nil } },
                           onRename: { renaming = month },
                           onOpen: { reading = month })
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .zIndex(1)
            }
        }
        .toolbar(opened == nil ? .visible : .hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showSettings) { SettingsView() }
        // a sealed month's posts are brought down when it opens, so Open and renaming have them
        .task(id: openedID) { if let id = openedID { await shelf.ensureDays(id) } }
        .fullScreenCover(item: $reading) { month in
            MonthBoardView(month: shelf.month(month.id) ?? month) { reading = nil }
        }
        .sheet(item: $renaming) { month in
            NameMonthView(heading: "Name \(month.full)", photos: month.photos, title: month.title, cover: month.cover, fallback: month.image) { title, cover in
                shelf.update(month.id, title: title, cover: cover)
                renaming = nil
            } onCancel: { renaming = nil }
        }
    }
}

#Preview("Shelf, empty") {
    ShelfView().environment(ProfileStore()).environment({ let s = ShelfStore(); s.months = []; return s }())
}
