import UIKit

/// Sample pictures for the seed posts, so the board shows real photos instead of the green placeholder.
/// (Swap or remove these once photos come from real posts.)
enum SamplePhotos {
    static let count = 4

    /// 1 is a landscape picture; 2 to 4 are portraits.
    static func image(_ n: Int) -> PostImage? {
        UIImage(named: "SamplePhoto\((n % count) + 1)").map { PostImage(uiImage: $0) }
    }
}
