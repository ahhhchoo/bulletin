import SwiftUI

/// Plays a GIF.
struct AnimatedGIFView: UIViewRepresentable {
    let data: Data
    /// A feed pauses the GIFs that have scrolled off screen.
    var playing = true

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.image = MediaProcessor.animatedImage(from: data)
        if !playing { view.stopAnimating() }
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        if playing, !view.isAnimating { view.startAnimating() }
        if !playing, view.isAnimating { view.stopAnimating() }
    }
}

/// A small "GIF" label for a still that will move when it is opened.
struct GIFBadge: View {
    var body: some View {
        Text("GIF")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(.black.opacity(0.55), in: Capsule())
            .accessibilityLabel("Animated picture")
    }
}

/// A picture in a feed or on a tile. A GIF plays its small feed animation while it is on screen and stops when it
/// scrolls away; with Reduce Motion on (or no animation) it is the still thumbnail.
///
/// For a picture that lives on the server, the animation is only downloaded once the tile is on screen.
struct FeedPicture: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let image: PostImage
    @State private var onScreen = false
    @State private var downloaded: Data?

    private var animation: Data? { image.feedGIF ?? downloaded }

    var body: some View {
        if (animation != nil || image.remote?.feedPath != nil), !reduceMotion {
            ZStack {
                Image(uiImage: image.uiImage).resizable().scaledToFill()
                if onScreen, let animation { AnimatedGIFView(data: animation) }
            }
            .onScrollVisibilityChange(threshold: 0.2) { onScreen = $0 }
            .task(id: onScreen) {
                guard onScreen, image.feedGIF == nil, downloaded == nil, let path = image.remote?.feedPath else { return }
                downloaded = try? await MediaCache.shared.data(path: path)
            }
        } else {
            Image(uiImage: image.uiImage).resizable().scaledToFill()
        }
    }
}

/// The full picture of an opened post: the 1600px photo, or the GIF playing. For a picture on the server it is
/// downloaded now, when the post is opened, and the thumbnail shows until it arrives.
struct FullPicture: View {
    let image: PostImage
    @State private var loadedImage: UIImage?
    @State private var loadedGIF: Data?

    var body: some View {
        Group {
            if let gif = image.gifData ?? loadedGIF {
                AnimatedGIFView(data: gif)
            } else {
                Image(uiImage: loadedImage ?? image.full).resizable().scaledToFill()
            }
        }
        .task(id: image.id) {
            guard let remote = image.remote, image.media == nil else { return }
            guard let data = try? await MediaCache.shared.data(path: remote.fullPath) else { return }
            if remote.isAnimated { loadedGIF = data } else { loadedImage = UIImage(data: data) }
        }
    }
}
