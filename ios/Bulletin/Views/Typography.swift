import SwiftUI
import UIKit
import CoreText

/// Design sizes that don't land exactly on a system text style are scaled with Dynamic Type
/// relative to the closest style, so they still respond to the user's text-size setting.
enum Typo {
    static func scaled(_ size: CGFloat, _ weight: Font.Weight, relativeTo style: Font.TextStyle) -> Font {
        let ui = UIFont.TextStyle(style)
        let scaled = UIFontMetrics(forTextStyle: ui).scaledValue(for: size)
        return .system(size: scaled, weight: weight)
    }

    /// Text you write on paper (sticky and page): 17pt semibold, scales with Dynamic Type.
    static var body17: Font { scaled(17, .semibold, relativeTo: .body) }

    /// JetBrains Mono (bundled in Fonts/, registered at launch): captions, dates, the prompt chat, anything typed.
    static let monoName = "JetBrainsMono-Regular"
    static func pixel(_ size: CGFloat) -> Font {
        let scaled = UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: size)
        return .custom(monoName, size: scaled)
    }

    /// The font file ships inside the app, so register it once before the first screen draws.
    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: monoName, withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

private extension UIFont.TextStyle {
    init(_ style: Font.TextStyle) {
        switch style {
        case .largeTitle: self = .largeTitle
        case .title: self = .title1
        case .title2: self = .title2
        case .title3: self = .title3
        case .headline: self = .headline
        case .subheadline: self = .subheadline
        case .callout: self = .callout
        case .footnote: self = .footnote
        case .caption: self = .caption1
        case .caption2: self = .caption2
        default: self = .body
        }
    }
}

/// Tiny press response used on every tappable thing: scale down on touch, spring back.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}
