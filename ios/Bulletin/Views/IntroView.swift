import SwiftUI

/// ONB intro: one paragraph that builds as you read. It pauses after "Jot down what's on your mind," until the sticky
/// has come and gone, scrolls up a little, adds "journal like you usually do," with the long note, scrolls again for
/// "keep things you want to remember," with the photo, then adds the last line and scrolls all the way up to sign-in.
/// The pieces are the board's real components. Tap anywhere to skip ahead.
struct IntroView: View {
    /// Called when someone chooses how to continue. Apple's own sign-in isn't wired up yet.
    let onFinish: (SignUpMethod) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: the paragraph, with its line breaks fixed so words never move once shown

    private static let titleRows: [[String]] = [["Welcome", "to"], ["your", "Bulletin."]]
    private static let bodyRows: [[String]] = [
        ["Jot", "down"], ["what’s", "on", "your"], ["mind,", "journal"], ["like", "you", "usually"],
        ["do,", "keep", "things"], ["you", "want", "to"], ["remember,", "and"], ["look", "back", "so"],
        ["you", "don’t"], ["forget."],
    ]
    /// How many words are on screen once each part has arrived: the title and "Jot down what's on your mind,",
    /// then "journal like you usually do,", then "keep things you want to remember,", then the rest.
    private static let chunkEnds = [10, 15, 21, 28]
    private static let fullText = "Welcome to your Bulletin. Jot down what’s on your mind, journal like you usually do, keep things you want to remember, and look back so you don’t forget."

    private static let rowHeight: CGFloat = 43
    private static let textSize: CGFloat = 48

    @State private var shown = 0
    @State private var scroll: CGFloat = 0
    @State private var piece: Piece?
    @State private var phase: Phase = .hidden
    @State private var stickyText = ""
    @State private var journalBody = ""
    @State private var photoBlur: CGFloat = 14
    @State private var endShown = 0
    @State private var buttonsIn = false
    @State private var skipTick = 0

    private enum Phase { case hidden, shown, leaving }
    private enum Piece { case sticky, journal, photo }

    private static let stickyFull = "omg just had the best iced coffee of my life. ok bye"
    private static let journalFull = "Walked the long way to work today. Got a coffee I didn’t need and sat in the park for ten minutes doing absolutely nothing. It was great."

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color("Paper").ignoresSafeArea()

                paragraph
                    .offset(y: -scroll)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Self.fullText)

                endLine

                if let piece { pieceView(piece).position(x: geo.size.width / 2, y: geo.size.height * 0.55) }

                // words slide up under the clock, so soften the top edge
                LinearGradient(colors: [Color("Paper"), Color("Paper").opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                    .allowsHitTesting(false)

                buttons
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .contentShape(.rect)
            .onTapGesture { skipTick += 1 }
        }
        .ignoresSafeArea()
        .task { await play() }
    }

    // MARK: text

    private var paragraph: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.titleRows.enumerated()), id: \.offset) { r, row in
                rowView(row, firstIndex: Self.titleRows.prefix(r).reduce(0) { $0 + $1.count })
            }
            Color.clear.frame(height: 56)
            ForEach(Array(Self.bodyRows.enumerated()), id: \.offset) { r, row in
                rowView(row, firstIndex: 4 + Self.bodyRows.prefix(r).reduce(0) { $0 + $1.count })
            }
        }
        .padding(.leading, 35)
        .padding(.top, 133)
    }

    /// The last screen, as in the Figma: "join / Bulletin" centered, with the paragraph scrolled away above it.
    private var endLine: some View {
        VStack(spacing: 14) {
            ForEach(Array(["join", "Bulletin"].enumerated()), id: \.offset) { i, word in
                let visible = endShown > i
                Text(word)
                    .font(.system(size: Self.textSize, weight: .heavy))
                    .tracking(-1.44)
                    .foregroundStyle(.black)
                    .frame(height: Self.rowHeight)
                    .opacity(visible ? 1 : 0)
                    .blur(radius: visible ? 0 : 12)
                    .scaleEffect(visible ? 1 : 0.94)
                    .animation(reduceMotion ? nil : .timingCurve(0.3, 0.7, 0.2, 1, duration: 0.85), value: visible)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 264)
        .accessibilityHidden(true)
    }

    private func rowView(_ words: [String], firstIndex: Int) -> some View {
        HStack(spacing: 11) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                let visible = firstIndex + i < shown
                Text(word)
                    .font(.system(size: Self.textSize, weight: .heavy))
                    .tracking(-1.44)
                    .foregroundStyle(.black)
                    .fixedSize()
                    .opacity(visible ? 1 : 0)
                    .blur(radius: visible ? 0 : 12)
                    .scaleEffect(visible ? 1 : 0.94)
                    .animation(reduceMotion ? nil : .timingCurve(0.3, 0.7, 0.2, 1, duration: 0.85), value: visible)
            }
        }
        .frame(height: Self.rowHeight)
    }

    // MARK: the pieces

    @ViewBuilder private func pieceView(_ piece: Piece) -> some View {
        let rotation: Double = switch piece { case .sticky: -3; case .journal: 2.5; case .photo: -2 }
        Group {
            switch piece {
            case .sticky:
                PostView(post: Post(kind: .sticky(text: stickyText.isEmpty ? " " : stickyText), rotation: 0), animated: false, tilt: 0)
            case .journal:
                PostView(post: Post(kind: .journal(title: "a slow, good day", body: journalBody.isEmpty ? " " : journalBody), rotation: 0), animated: false, tilt: 0, backSheet: .intro)
            case .photo:
                PostView(post: Post(kind: .photo(caption: "sandwiches at alamo square"), rotation: 0, image: SamplePhotos.onboarding), animated: false, tilt: 0)
                    .blur(radius: photoBlur)
            }
        }
        .scaleEffect(1.6)
        .shadow(color: .black.opacity(0.28), radius: 24, y: 18)
        .rotationEffect(.degrees(phase == .hidden ? rotation - 4 : rotation))
        .scaleEffect(phase == .hidden ? 0.86 : (phase == .leaving ? 0.94 : 1))
        .offset(y: phase == .hidden ? 26 : (phase == .leaving ? -34 : 0))
        .opacity(phase == .shown ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: sign-in

    private var buttons: some View {
        VStack(spacing: 14) {
            Button { onFinish(.phone) } label: {
                Text("Continue with Phone")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.black, in: Capsule())
            }
            .buttonStyle(PressableStyle())

            // Same type as the phone button so the two read as a pair. Not wired to an account yet.
            Button { onFinish(.apple) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo")
                    Text("Continue with Apple")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.white, in: Capsule())
                .overlay(Capsule().strokeBorder(.black.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())

            // The two names will open the real pages once they exist.
            (Text("By pressing on “Continue with…” you agree to our ")
             + Text("Terms of Service").underline()
             + Text(" and ")
             + Text("Privacy Policy").underline())
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 14)
        }
        .padding(.horizontal, 27)
        .padding(.bottom, 40)
        .offset(y: buttonsIn ? 0 : 70)
        .opacity(buttonsIn ? 1 : 0)
        .allowsHitTesting(buttonsIn)
    }

    // MARK: the timeline

    private var pace: Double { reduceMotion ? 0.05 : 1 }

    /// A pause that a tap cuts short.
    private func wait(_ ms: Int) async {
        let end = Date().addingTimeInterval(Double(ms) / 1000 * pace)
        let tick = skipTick
        while Date() < end, tick == skipTick, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(30)) }
    }

    private func reveal(upTo count: Int, step: Int) async {
        while shown < count, !Task.isCancelled {
            shown += 1
            await wait(step)
        }
    }

    @MainActor private func play() async {
        // the first part, then a pause long enough to read it before the sticky arrives
        await reveal(upTo: 4, step: 50)
        await wait(250)
        await reveal(upTo: Self.chunkEnds[0], step: 40)
        await wait(750)

        for (i, p) in [Piece.sticky, .journal, .photo].enumerated() {
            await show(p)
            await wait(p == .photo ? 3000 : 3900)
            await hidePiece()
            // the page scrolls up a little, then the next words arrive
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.9 * pace)) { scroll += 95 }
            await wait(950)
            await reveal(upTo: Self.chunkEnds[i + 1], step: 40)
            await wait(i < 2 ? 800 : 1400)
        }

        // the paragraph scrolls all the way away, "join Bulletin" arrives, then sign-in
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 1.1 * pace)) { scroll = 790 }
        await wait(900)
        endShown = 1
        await wait(250)
        endShown = 2
        await wait(600)
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.75 * pace)) { buttonsIn = true }
    }

    @MainActor private func show(_ p: Piece) async {
        stickyText = ""; journalBody = ""; photoBlur = p == .photo ? 14 : 0
        phase = .hidden
        piece = p
        try? await Task.sleep(for: .milliseconds(60))
        withAnimation(reduceMotion ? nil : .spring(duration: 0.85, bounce: 0.25)) { phase = .shown }
        switch p {
        case .sticky: Task { await typeSticky() }
        case .journal: Task { await typeJournal() }
        case .photo: withAnimation(.easeOut(duration: 1.1 * pace).delay(0.1)) { photoBlur = 0 }
        }
    }

    @MainActor private func hidePiece() async {
        withAnimation(.easeIn(duration: 0.43 * pace)) { phase = .leaving }
        await wait(520)
        piece = nil
    }

    private func typeSticky() async {
        try? await Task.sleep(for: .milliseconds(Int(900 * pace)))
        for c in Self.stickyFull {
            if Task.isCancelled || piece != .sticky { return }
            stickyText.append(c)
            try? await Task.sleep(for: .milliseconds(Int(48 * pace)))
        }
    }

    private func typeJournal() async {
        try? await Task.sleep(for: .milliseconds(Int(900 * pace)))
        for w in Self.journalFull.split(separator: " ") {
            if Task.isCancelled || piece != .journal { return }
            journalBody += (journalBody.isEmpty ? "" : " ") + w
            try? await Task.sleep(for: .milliseconds(Int(60 * pace)))
        }
    }
}

#Preview { IntroView(onFinish: { _ in }) }
