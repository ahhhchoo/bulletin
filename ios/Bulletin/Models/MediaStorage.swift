import Foundation
import FirebaseStorage

/// Where processed media goes, and how it is stored. Written for Firebase Storage, with no SDK yet: when the backend
/// is connected, `FirebaseMediaStore` implements `MediaStore` and nothing else in the app has to change.
///
/// What keeps the bill small (Firebase charges for downloads, so this is about making each download tiny and rare):
///  - Every picture is stored twice: a ~480px thumbnail (feeds, board tiles, the Shared tab) and the full picture
///    (at most 1600px, loaded only when a post is opened). A GIF is stored three times: its first frame as the thumbnail,
///    a small animation (about 320px) that plays in feeds while on screen, and the 480px GIF for when it is opened.
///  - The file name includes a hash of its bytes, so a file is never overwritten. That is what makes
///    `Cache-Control: public, max-age=31536000, immutable` safe: phones and any CDN keep it and never ask again.
///  - A post's database record stores the paths, size and aspect ratio, so a feed can lay out its tiles from the record
///    alone and then fetch only thumbnails.
struct MediaUploadPlan {
    /// One year, and "immutable": the name changes if the picture ever does.
    static let cacheControl = "public, max-age=31536000, immutable"

    let fullPath: String
    let thumbPath: String
    /// A GIF's feed animation. nil for pictures.
    let feedPath: String?
    let fullContentType: String
    let thumbContentType = "image/jpeg"

    init(_ media: ProcessedMedia, userID: String) {
        fullPath = "posts/\(userID)/\(media.hash).\(media.fullExtension)"
        thumbPath = "posts/\(userID)/\(media.hash)_t.jpg"
        feedPath = media.feed == nil ? nil : "posts/\(userID)/\(media.hash)_f.gif"
        fullContentType = media.fullContentType
    }
}

/// What is saved on a post so any phone can find its pictures again.
struct StoredMedia: Codable, Hashable {
    var fullPath: String
    var thumbPath: String
    var feedPath: String?
    var width: Int
    var height: Int
    var isAnimated: Bool
}

protocol MediaStore {
    func upload(_ media: ProcessedMedia, userID: String) async throws -> StoredMedia
}

/// Used until the backend exists: nothing leaves the phone.
struct LocalMediaStore: MediaStore {
    func upload(_ media: ProcessedMedia, userID: String) async throws -> StoredMedia {
        let plan = MediaUploadPlan(media, userID: userID)
        return StoredMedia(fullPath: plan.fullPath, thumbPath: plan.thumbPath, feedPath: plan.feedPath, width: media.width, height: media.height, isAnimated: media.kind == .gif)
    }
}

/// Uploads to Firebase Storage. The files are named for their contents and marked cacheable for a year, so the
/// phone (and Google's servers) keep them and never ask again.
struct FirebaseMediaStore: MediaStore {
    func upload(_ media: ProcessedMedia, userID: String) async throws -> StoredMedia {
        let plan = MediaUploadPlan(media, userID: userID)
        let storage = Storage.storage()

        func put(_ data: Data, to path: String, type: String) async throws {
            let meta = StorageMetadata()
            meta.contentType = type
            meta.cacheControl = MediaUploadPlan.cacheControl
            _ = try await storage.reference(withPath: path).putDataAsync(data, metadata: meta)
        }
        // the three files go up together
        async let full: Void = put(media.full, to: plan.fullPath, type: plan.fullContentType)
        async let thumb: Void = put(media.thumb, to: plan.thumbPath, type: plan.thumbContentType)
        async let feed: Void = {
            if let feedData = media.feed, let path = plan.feedPath { try await put(feedData, to: path, type: "image/gif") }
        }()
        _ = try await (full, thumb, feed)

        return StoredMedia(fullPath: plan.fullPath, thumbPath: plan.thumbPath, feedPath: plan.feedPath,
                           width: media.width, height: media.height, isAnimated: media.kind == .gif)
    }

    /// Deletes a post's files (used when the post is deleted, so nothing is left to pay for).
    static func delete(_ media: StoredMedia) async {
        let storage = Storage.storage()
        for path in [media.fullPath, media.thumbPath, media.feedPath].compactMap({ $0 }) {
            try? await storage.reference(withPath: path).delete()
        }
    }
}
