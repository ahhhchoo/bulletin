import SwiftUI

/// A stand-in for an empty state that has not been designed yet. Every empty screen that still needs a design uses
/// this, so they are easy to find (search "EmptyStatePlaceholder") and to swap out one by one.
struct EmptyStatePlaceholder: View {
    /// What this screen is, in a few words.
    let title: String
    /// The screen's code in the product spec, when it has one (for example "BRD-08").
    var code: String?
    /// What the empty state should do once it is designed.
    var intent: String

    var body: some View {
        VStack(spacing: 8) {
            Text("PLACEHOLDER" + (code.map { " · \($0)" } ?? ""))
                .font(Typo.pixel(11))
                .foregroundStyle(.black.opacity(0.4))
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
            Text("Needs to be designed. " + intent)
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24).padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.black.opacity(0.2), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("Empty states") {
    ScrollView {
        VStack(spacing: 16) {
            EmptyStatePlaceholder(title: "A new month", code: "BRD-08",
                                  intent: "Shows on an empty board and doubles as the first-post screen.")
            EmptyStatePlaceholder(title: "Nobody has added you yet", code: "FRN-02",
                                  intent: "Explains the Shared tab and has an invite button.")
            EmptyStatePlaceholder(title: "Nothing on your shelf yet",
                                  intent: "Sealed months show up here once a month ends.")
        }
        .padding(20)
    }
    .background(Color("Paper"))
}
