import SwiftUI
import UIKit

/// One sealed month on the shelf.
struct ShelfMonth: Identifiable {
    let id = UUID()
    let short: String
    let year: String
    let title: String
    /// Which sample photo leads the card.
    let photo: Int
    var full = ""
    var pins = 0
    var notes = 0
    var busiest = 0

    var image: UIImage? { SamplePhotos.image(photo)?.uiImage }
    var palette: AmbientPalette? { palette(softness: AmbientPalette.softness) }

    func palette(softness: Double) -> AmbientPalette? {
        image.map { AmbientPalette.of($0, key: photo, softness: softness) }
    }

    static let all: [ShelfMonth] = [
        .init(short: "Oct", year: "26", title: "The month of Yzma", photo: 0, full: "October", pins: 24, notes: 31, busiest: 14),
        .init(short: "Sep", year: "26", title: "Back to school", photo: 1, full: "September", pins: 17, notes: 12, busiest: 3),
        .init(short: "Aug", year: "26", title: "Beach, mostly", photo: 2, full: "August", pins: 31, notes: 22, busiest: 21),
        .init(short: "Jul", year: "26", title: "No plans", photo: 3, full: "July", pins: 9, notes: 5, busiest: 4),
        .init(short: "Jun", year: "26", title: "Moved apartments", photo: 1, full: "June", pins: 28, notes: 19, busiest: 12),
        .init(short: "May", year: "26", title: "Slow mornings", photo: 3, full: "May", pins: 12, notes: 7, busiest: 5),
        .init(short: "Apr", year: "26", title: "Tulips", photo: 2, full: "April", pins: 14, notes: 8, busiest: 9),
        .init(short: "Mar", year: "26", title: "The long rain", photo: 0, full: "March", pins: 21, notes: 15, busiest: 18),
    ]
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
        let id = key * 1000 + Int((softness * 100).rounded())
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
                Text("\(month.title.lowercased()) · sealed")
                    .font(Typo.pixel(13)).opacity(0.6)
                    .padding(.top, 14)

                HStack(spacing: 26) {
                    stat(month.pins, "pinned"); stat(month.notes, "notes"); stat(month.busiest, "busiest day")
                }
                .padding(.top, 20)

                VStack(spacing: 10) {
                    action("Open \(month.full)", main: true)
                    action("Notes from friends")
                    action("Recap")
                    action("Mark \u{201C}just for me\u{201D}")
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

    private func action(_ title: String, main: Bool = false) -> some View {
        Button {} label: {
            Text(title).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(main ? .white : text)
                .frame(minWidth: 150)
                .padding(.horizontal, 20).padding(.vertical, 11)
                .background(main ? Color.black : Color.white.opacity(0.4), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// The shelf: sealed months in a cascade. A card is straight near the middle of the screen and tilts, shrinks and
/// fades the further it sits from there, so the stack feels like it is being flipped through.
struct ShelfView: View {
    @State private var viewport: CGFloat = 874
    @State private var opened: ShelfMonth?

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(Array(ShelfMonth.all.enumerated()), id: \.element.id) { i, month in
                        let vh = viewport
                        MonthCard(month: month)
                            .onTapGesture { withAnimation(.spring(duration: 0.45, bounce: 0.2)) { opened = month } }
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

            Text("Shelf")
                .font(.system(size: 26, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20).padding(.top, 8)

            if let month = opened {
                MonthSheet(month: month) { withAnimation(.spring(duration: 0.4, bounce: 0.1)) { opened = nil } }
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .zIndex(1)
            }
        }
        .toolbar(opened == nil ? .visible : .hidden, for: .tabBar)
    }
}
