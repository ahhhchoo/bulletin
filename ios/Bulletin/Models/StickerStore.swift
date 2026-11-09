import SwiftUI
import PhotosUI
import Vision
import CoreImage

/// Something you can stick on a friend's board. Either a drawn one that ships with the app,
/// or a cutout you made from one of your own photos.
struct Sticker: Identifiable, Hashable {
    let id: String
    var symbol: String?          // SF Symbol stand-in until the real stickers are exported from Figma
    var tint: Color?
    var image: UIImage?          // a cutout from a photo

    static func == (l: Sticker, r: Sticker) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var isMine: Bool { image != nil }
}

@Observable
final class StickerStore {
    /// Placeholders. When the real stickers are exported from Figma they go in the asset catalog and
    /// replace these (a `Sticker` with an asset name instead of a symbol).
    let bundled: [Sticker] = [
        Sticker(id: "heart", symbol: "heart.fill", tint: Color(red: 1, green: 0.45, blue: 0.45)),
        Sticker(id: "star", symbol: "star.fill", tint: Color(red: 1, green: 0.8, blue: 0.2)),
        Sticker(id: "sparkles", symbol: "sparkles", tint: Color(red: 0.55, green: 0.6, blue: 1)),
        Sticker(id: "sun", symbol: "sun.max.fill", tint: Color(red: 1, green: 0.62, blue: 0.2)),
        Sticker(id: "leaf", symbol: "leaf.fill", tint: Color(red: 0.4, green: 0.78, blue: 0.5)),
        Sticker(id: "cup", symbol: "cup.and.saucer.fill", tint: Color(red: 0.7, green: 0.5, blue: 0.38)),
        Sticker(id: "flame", symbol: "flame.fill", tint: Color(red: 1, green: 0.4, blue: 0.25)),
        Sticker(id: "moon", symbol: "moon.stars.fill", tint: Color(red: 0.5, green: 0.45, blue: 0.85)),
    ]
    /// Cutouts you made, newest first.
    var mine: [Sticker] = []
    /// The one shown in the dock, and the one you drag out.
    var selected: Sticker

    init() { selected = bundled[0] }

    var all: [Sticker] { mine + bundled }

    func add(cutout: UIImage) {
        let s = Sticker(id: UUID().uuidString, image: cutout)
        mine.insert(s, at: 0)
        selected = s
    }

    func remove(_ s: Sticker) {
        mine.removeAll { $0.id == s.id }
        if selected.id == s.id { selected = bundled[0] }
    }
}

/// Lifts the main subject out of a photo (like Live Stickers) and gives it a white sticker border.
enum StickerMaker {
    enum Failure: LocalizedError {
        case unreadable, noSubject, unsupported
        var errorDescription: String? {
            switch self {
            case .unreadable: "Couldn’t open that photo."
            case .unsupported: "This device can’t lift subjects out of photos (the iOS Simulator can’t either)."
            case .noSubject: "Couldn’t find a subject in that photo. Try one with a clear person or object."
            }
        }
    }

    static func cutout(from data: Data) async throws -> UIImage {
        guard let ui = UIImage(data: data) else { throw Failure.unreadable }
        return try await Task.detached(priority: .userInitiated) { try make(from: ui) }.value
    }

    private static func make(from original: UIImage) throws -> UIImage {
        // Redraw upright and at a sane size first, so orientation and memory are not a worry.
        let factor = min(1, 1024 / max(original.size.width, original.size.height))
        let size = CGSize(width: original.size.width * factor, height: original.size.height * factor)
        let upright = UIGraphicsImageRenderer(size: size).image { _ in original.draw(in: CGRect(origin: .zero, size: size)) }
        guard let cg = upright.cgImage else { throw Failure.unreadable }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg)
        do { try handler.perform([request]) } catch { throw Failure.unsupported }
        guard let result = request.results?.first, !result.allInstances.isEmpty else { throw Failure.noSubject }

        let buffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true)
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let subject = CIContext().createCGImage(ci, from: ci.extent) else { throw Failure.noSubject }
        return outlined(UIImage(cgImage: subject), maxSide: 360)
    }

    /// Draws a white silhouette a few points out in every direction, then the cutout on top.
    private static func outlined(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let border: CGFloat = 8
        let k = min(1, (maxSide - border * 2) / max(image.size.width, image.size.height))
        let w = image.size.width * k, h = image.size.height * k
        let canvas = CGSize(width: w + border * 2, height: h + border * 2)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        let white = image.withRenderingMode(.alwaysTemplate)
        return UIGraphicsImageRenderer(size: canvas, format: fmt).image { ctx in
            let rect = CGRect(x: border, y: border, width: w, height: h)
            UIColor.white.setFill()
            for step in 0..<20 {
                let a = CGFloat(step) / 20 * 2 * .pi
                let r = rect.offsetBy(dx: cos(a) * border * 0.9, dy: sin(a) * border * 0.9)
                white.withTintColor(.white, renderingMode: .alwaysTemplate).draw(in: r)
            }
            image.draw(in: rect)
        }
    }
}
