import UIKit
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

/// A picture or GIF, already shrunk and re-encoded so it is cheap to store and to show. Nothing bigger than this is
/// ever kept or uploaded: a phone photo is a few megabytes, and downloads (egress) are what the backend bill is made of.
struct ProcessedMedia {
    enum Kind: String { case photo, gif }

    let kind: Kind
    /// What opening the post shows: a JPEG at most 1600 pixels on a side, or the shrunk GIF.
    let full: Data
    /// The still picture: a small JPEG (for a GIF, its first frame). Shown while a feed is loading, with Reduce Motion
    /// on, and anywhere a still is wanted.
    let thumb: Data
    /// For a GIF only: a smaller animation (about 280px, 24 frames at most, under 300 KB) that plays in feeds and tiles
    /// while they are on screen. The full GIF is only downloaded when a post is opened.
    let feed: Data?
    let width: Int
    let height: Int
    /// A short fingerprint of `full`. Used in the file name, so a file never changes and can be cached forever.
    let hash: String

    var aspect: Double { Double(width) / Double(max(height, 1)) }
    var fullContentType: String { kind == .gif ? "image/gif" : "image/jpeg" }
    var fullExtension: String { kind == .gif ? "gif" : "jpg" }
    var totalBytes: Int { full.count + thumb.count + (feed?.count ?? 0) }
}

enum MediaError: Error {
    case unreadable
    case tooLarge
}

enum MediaProcessor {
    static let photoMaxSide = 1600
    static let thumbMaxSide = 480
    /// Profile pictures show at most a couple of hundred points wide.
    static let avatarMaxSide = 512
    static let gifMaxSide = 480
    static let gifMaxFrames = 48
    /// The feed animation: smaller and shorter than the full GIF.
    static let feedMaxSide = 280
    static let feedMaxFrames = 24
    static let feedMaxBytes = 300_000
    /// A GIF is shrunk in steps (smaller frames) until it is under this.
    static let gifMaxBytes = 2_500_000
    /// Nobody gets to push a huge file through the processor.
    static let maxInputBytes = 40_000_000

    // MARK: entry points

    /// Shrinks whatever the photo picker gave us. Runs off the main thread.
    static func process(_ data: Data) async throws -> ProcessedMedia {
        try await Task.detached(priority: .userInitiated) { try processNow(data) }.value
    }

    /// A small square-friendly picture for a profile photo.
    static func avatar(from data: Data) -> UIImage? {
        guard data.count <= maxInputBytes, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = downsample(source, index: 0, maxSide: avatarMaxSide) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: pictures and GIFs

    static func processNow(_ data: Data) throws -> ProcessedMedia {
        guard data.count <= maxInputBytes else { throw MediaError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            throw MediaError.unreadable
        }
        let isGIF = (CGImageSourceGetType(source) as String?) == UTType.gif.identifier && CGImageSourceGetCount(source) > 1
        return isGIF ? try gif(source) : try photo(source)
    }

    private static func photo(_ source: CGImageSource) throws -> ProcessedMedia {
        guard let full = downsample(source, index: 0, maxSide: photoMaxSide),
              let thumb = downsample(source, index: 0, maxSide: thumbMaxSide),
              let fullData = jpeg(full, quality: 0.8),      // re-encoding also drops EXIF, including GPS
              let thumbData = jpeg(thumb, quality: 0.7) else { throw MediaError.unreadable }
        return ProcessedMedia(kind: .photo, full: fullData, thumb: thumbData, feed: nil, width: full.width, height: full.height, hash: hash(fullData))
    }

    private static func gif(_ source: CGImageSource) throws -> ProcessedMedia {
        let count = CGImageSourceGetCount(source)
        let gifData = try encodeGIF(source, count: count, maxFrames: gifMaxFrames, sides: [gifMaxSide, 400, 320, 240], maxBytes: gifMaxBytes)
        guard gifData.count <= gifMaxBytes * 2 else { throw MediaError.tooLarge }
        // The smaller animation that feeds play.
        let feedData = try encodeGIF(source, count: count, maxFrames: feedMaxFrames, sides: [feedMaxSide, 240, 200, 160], maxBytes: feedMaxBytes)
        guard let first = downsample(source, index: 0, maxSide: thumbMaxSide), let thumbData = jpeg(first, quality: 0.7) else { throw MediaError.unreadable }
        return ProcessedMedia(kind: .gif, full: gifData, thumb: thumbData, feed: feedData, width: first.width, height: first.height, hash: hash(gifData))
    }

    /// Re-encodes a GIF with fewer, smaller frames. Long GIFs lose frames (keeping the same total time); the frame size
    /// then steps down until the file is under `maxBytes`.
    private static func encodeGIF(_ source: CGImageSource, count: Int, maxFrames: Int, sides: [Int], maxBytes: Int) throws -> Data {
        let stride = max(Int((Double(count) / Double(maxFrames)).rounded(.up)), 1)
        var frames: [(index: Int, delay: Double)] = []
        var i = 0
        while i < count {
            var delay = 0.0
            for j in i..<min(i + stride, count) { delay += frameDelay(source, j) }
            frames.append((i, max(delay, 0.04)))
            i += stride
        }
        var best: Data?
        for side in sides {
            let out = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(out, UTType.gif.identifier as CFString, frames.count, nil) else { throw MediaError.unreadable }
            CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            for f in frames {
                guard let cg = downsample(source, index: f.index, maxSide: side) else { throw MediaError.unreadable }
                CGImageDestinationAddImage(dest, cg, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: f.delay]] as CFDictionary)
            }
            guard CGImageDestinationFinalize(dest) else { throw MediaError.unreadable }
            best = out as Data
            if out.length <= maxBytes { break }
        }
        guard let data = best else { throw MediaError.unreadable }
        return data
    }

    // MARK: ImageIO helpers

    /// Decodes at the target size (never the full camera resolution) and applies the photo's rotation.
    private static func downsample(_ source: CGImageSource, index: Int, maxSide: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
    }

    private static func jpeg(_ image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    private static func frameDelay(_ source: CGImageSource, _ index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let d = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
        return d < 0.02 ? 0.1 : d
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: playing a GIF

    /// The frames of a (shrunk) GIF as one animated image, for the opened post.
    static func animatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var total = 0.0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cg))
            total += frameDelay(source, i)
        }
        guard !images.isEmpty else { return nil }
        return UIImage.animatedImage(with: images, duration: max(total, 0.2))
    }
}
