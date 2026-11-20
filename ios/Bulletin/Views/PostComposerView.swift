import SwiftUI
import PhotosUI

/// BRD-04 Composer / clip to past day.
///
/// You write on the paper itself. A sticky note grows into a page (with an optional title) when the
/// entry gets long: the sticky lifts, opens in two stages with a faint crease that smooths out, and
/// settles flat ("B2 + B4, crease-led" from the prototypes).
struct PostComposerView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var dayID: Int
    @State private var text = ""
    @State private var title = ""
    @State private var stickyColor: StickyColor = .yellow
    @State private var shownName: StickyColor?       // the color's nickname, bouncing above the swatches for a moment
    @State private var nameBounce = 0
    @State private var nameTask: Task<Void, Never>?
    @FocusState private var focused: Bool
    @FocusState private var captionFocused: Bool

    // Two things you can make: write something, or pin a picture. They sit side by side as two cards;
    // the one you are not on peeks in from the edge so you can always see the other option.
    enum PageMode: Int { case write, picture, past }
    private typealias Mode = PageMode
    @State private var mode: Mode = .write
    @State private var caption = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var photo: PostImage?
    @State private var showPicker = false
    @State private var showPast = false              // "from my posts": answer the prompt with an older post

    // paper state
    @State private var isPage = false
    @State private var paperSize = CGSize(width: Metrics.stickyWidth, height: Metrics.stickyHeight)
    @State private var whiteness = 0.0              // 0 = sticky green, 1 = white page
    @State private var unfoldTrigger = 0            // fires the lift / crease keyframes
    @State private var landed = 0                   // fires the soft haptic when the page lands
    @State private var morphTask: Task<Void, Never>?
    @State private var available = CGSize(width: 402, height: 600)
    @State private var textHeight: CGFloat = 0      // rendered height of the text at sticky width

    /// Set when editing an existing post: the composer opens with its text, on its day, and "Save" replaces it.
    private let editing: Post?

    init(todayID: Int, editing: (post: Post, dayID: Int)? = nil) {
        self.editing = editing?.post
        _dayID = State(initialValue: editing?.dayID ?? todayID)
        switch editing?.post.kind {
        case .sticky(let t)?:
            _text = State(initialValue: t)
            _stickyColor = State(initialValue: editing?.post.stickyColor ?? .yellow)
        case .photo(let c)?:
            // Editing a photo means editing its caption: the picture stays as it was pinned.
            _caption = State(initialValue: c)
            _photo = State(initialValue: editing?.post.image)
            _mode = State(initialValue: .picture)
        case .journal(let t, let b)?:
            _title = State(initialValue: t)
            _text = State(initialValue: b)
            _isPage = State(initialValue: true)                  // already a page: open flat, no unfold
            _whiteness = State(initialValue: 1)
            _paperSize = State(initialValue: CGSize(width: Metrics.pageWidth, height: Metrics.pageHeight))
        default:
            break
        }
    }

    private enum Metrics {
        static let stickySide: CGFloat = 246      // the photo and "from my posts" cards
        /// The sticky is the posted 140 x 160 sticky, just bigger, so what you write is the shape that gets pinned.
        static let stickyScale: CGFloat = 1.5
        static let stickyWidth: CGFloat = 140 * stickyScale
        static let stickyHeight: CGFloat = 160 * stickyScale
        static let pageWidth: CGFloat = 362
        static let pageHeight: CGFloat = 485
        // The sticky holds as much text as fits in its square, minus padding. Past that, it becomes a page.
        // Measured as rendered height, so wrapped lines and blank lines both count.
        static let stickyInnerWidth: CGFloat = stickyWidth - 20 - 20
        static let stickyMaxTextHeight: CGFloat = stickyHeight - 24 - 20
        static let switchBackSlack: CGFloat = 24    // about one line of hysteresis, so it doesn't flicker at the edge
        static let stage1Height: CGFloat = 270      // crease-led: first stage is shallow
    }

    /// Editing keeps the post's own state: an original post on a past day is not a clipped addition.
    private var isClip: Bool { editing?.isClipped ?? (dayID != store.todayID) }
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Writing needs words; a picture needs a photo (its caption is optional).
    private var canSubmit: Bool {
        switch mode {
        case .write: !trimmed.isEmpty
        case .picture: photo != nil || isEditingPhoto
        case .past: false          // choosing from your posts happens in its own picker
        }
    }

    /// The pages you can swipe through, left to right.
    private var modes: [Mode] { answeringPrompt ? [.write, .picture, .past] : [.write, .picture] }
    /// Editing a post is only ever about its words, so the picture side is not offered there.
    private var offersPicture: Bool { editing == nil }
    /// Editing a photo post opens on the picture page, with the caption ready to change.
    private var isEditingPhoto: Bool { if case .photo? = editing?.kind { return true } else { return false } }

    private var answeringPrompt: Bool { store.answeringPrompt && editing == nil }

    private var placeholder: String {
        if store.answeringPrompt { return "answer the prompt…" }
        return isClip ? "add to \(store.shortLabel(dayID))…" : "What’s on your mind?"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DayHeader(dayID: $dayID, isClip: isClip, editable: editing == nil)
                    .padding(.top, 2)

                if answeringPrompt {
                    promptBlock
                        .padding(.top, 14)
                }

                pager
                    .padding(.top, answeringPrompt ? 22 : 36)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .background(Color("Paper"))
            .onGeometryChange(for: CGSize.self, of: \.size) { available = $0 }
            // The switch is pinned just above the keyboard, so a longer caption can never push it around.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if mode == .write && !isPage && !isEditingPhoto { colorRow }
                    if offersPicture {
                        modeSwitch
                            .frame(maxWidth: .infinity)
                            .opacity(isPage ? 0 : 1)              // a long page owns the screen
                            .allowsHitTesting(!isPage)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing != nil ? "Save" : (isClip ? "Clip" : "Pin"), action: editing != nil ? save : post)
                        .fontWeight(.semibold)
                        .disabled(!canSubmit)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color("Paper"))
        .tint(.black)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: landed)
        .sensoryFeedback(.success, trigger: store.postCount)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.75), trigger: mode)     // a crisp click when you switch write / picture
        .photosPicker(isPresented: $showPicker, selection: $pickedItem, matching: .images)
        .sheet(isPresented: $showPast) {
            PastPostPicker { id in
                store.answerPrompt(with: id)
                dismiss()
            }
        }
        .onAppear {
            if isEditingPhoto {
                Task { try? await Task.sleep(for: .milliseconds(350)); captionFocused = true }
            } else {
                focused = true
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { await attach(item) }
        }
        .onChange(of: caption) { _, new in
            // Write as much as you like (up to a point). The board shows two lines of it; tapping the photo shows all.
            let flat = new.replacingOccurrences(of: "\n", with: " ")
            if flat.count > PhotoMetrics.captionLimit { caption = String(flat.prefix(PhotoMetrics.captionLimit)) } else if flat != new { caption = flat }
        }
        .onChange(of: available) {
            // an opened page fills the room above the keyboard, whatever the device
            if isPage && paperSize.height > Metrics.stage1Height + 1 { paperSize = pageSize(stage: 2) }
        }
        .onChange(of: textHeight) { _, h in
            guard mode == .write else { return }
            if !isPage && h > Metrics.stickyMaxTextHeight { setPage(true) }
            else if isPage && h <= Metrics.stickyMaxTextHeight - Metrics.switchBackSlack { setPage(false) }
        }
    }

    // MARK: - write | picture

    /// Both cards, and swiping between the two (the switch itself is pinned above the keyboard).
    private var pager: some View {
        let shift = available.width / 2 + 18          // how far the other card sits off to the side
        let peek: CGFloat = 0.608                     // the peeking card is about 60% size, as in the design

        return VStack(spacing: 0) {
            ZStack {
                if !isEditingPhoto {
                    paper
                        .modifier(PageSlot(mode: mode, own: .write, shift: shift, peek: peek, lift: 0))
                        .allowsHitTesting(mode == .write)
                        .accessibilityHidden(mode != .write)
                }

                if (offersPicture || isEditingPhoto) && !isPage {
                    pictureCard
                        .modifier(PageSlot(mode: mode, own: .picture, shift: shift, peek: peek, lift: -12))
                        .transition(.opacity)

                    if answeringPrompt {
                        pastCard
                            .modifier(PageSlot(mode: mode, own: .past, shift: shift, peek: peek, lift: -12))
                            .transition(.opacity)
                    }
                }
            }
            .frame(height: pagerHeight)
            .contentShape(.rect)
            .simultaneousGesture(swipe)
        }
    }

    /// While answering the prompt, its text stays above the paper so you can see the question.
    private var promptBlock: some View {
        VStack(spacing: 6) {
            PromptTag()
            Text(store.prompt)
                .font(Typo.scaled(17, .medium, relativeTo: .body))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Prompt: \(store.prompt)")
    }

    private var pagerHeight: CGFloat {
        if isPage { return paperSize.height }
        if mode == .picture, let photo { return pictureFaceHeight(photo) + 54 }   // room for a two-line caption
        return mode == .write ? Metrics.stickyHeight : Metrics.stickySide
    }

    private func pictureFaceHeight(_ image: PostImage) -> CGFloat {
        min(Metrics.stickySide / image.pinAspect, answeringPrompt ? 236 : 290)     // keeps the photo's shape, but never crowds the keyboard
    }

    /// The seven sticky colors, as round swatches above the switch. A long entry becomes a white page, which has none.
    private var colorRow: some View {
        HStack(spacing: 14) {
            ForEach(StickyColor.allCases) { color in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { stickyColor = color }
                    showName(color)
                } label: {
                    Circle().fill(color.body)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().strokeBorder(.black.opacity(stickyColor == color ? 0.4 : 0), lineWidth: 2).padding(-4))
                        .padding(4)
                        .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(color.nickname) sticky")
                .accessibilityAddTraits(stickyColor == color ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
        .overlay(alignment: .top) { nameTag }
        // a soft tap on every press (even on the color you already have), a touch firmer for each swatch along the row
        .sensoryFeedback(trigger: nameBounce) { _, _ in
            let i = StickyColor.allCases.firstIndex(of: stickyColor) ?? 0
            return .impact(flexibility: .soft, intensity: 0.55 + 0.07 * Double(i))
        }
        .transition(.opacity)
    }

    /// The nickname pops up over the swatch you picked: a little hop with a bounce, then it fades.
    @ViewBuilder private var nameTag: some View {
        if let color = shownName, let i = StickyColor.allCases.firstIndex(of: color) {
            let middle = CGFloat(StickyColor.allCases.count - 1) / 2
            NameTag(color: color, bounce: nameBounce)
                .offset(x: (CGFloat(i) - middle) * 52)     // over the swatch (38 wide, 14 apart)
                .allowsHitTesting(false)
                .transition(.opacity)
                .accessibilityHidden(true)
        }
    }

    private func showName(_ color: StickyColor) {
        nameTask?.cancel()
        shownName = color
        nameBounce += 1
        nameTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { shownName = nil }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 14) {
            modeButton("write", .write)
            modeButton("picture", .picture)
            if answeringPrompt { modeButton("from my posts", .past) }
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(Color("Paper").opacity(0.94))
        .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.08)).frame(height: 0.5) }
    }

    private func modeButton(_ title: String, _ target: Mode) -> some View {
        Button { go(target, opening: true) } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(mode == target ? .black : .black.opacity(0.2))
                .padding(10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.25), value: mode)
        .accessibilityAddTraits(mode == target ? .isSelected : [])
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard offersPicture, !isPage,
                      abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                guard let i = modes.firstIndex(of: mode) else { return }
                // swiping only moves between pages; it never opens the photo picker by itself
                if value.translation.width < -50, i + 1 < modes.count { go(modes[i + 1]) }
                else if value.translation.width > 50, i > 0 { go(modes[i - 1]) }
            }
    }

    /// `opening`: a tap on a label or on the peeking card opens its picker straight away. A swipe never does.
    private func go(_ target: Mode, opening: Bool = false) {
        guard target != mode, offersPicture else { return }
        focused = false
        captionFocused = false
        withAnimation(.spring(duration: 0.5, bounce: 0.18)) { mode = target }
        Task {
            try? await Task.sleep(for: .milliseconds(420))      // let the cards finish sliding first
            guard mode == target else { return }
            switch target {
            case .write: focused = true
            case .picture:
                if photo != nil { captionFocused = true }
                else if opening { showPicker = true }           // tapping "picture" opens your photos right away
            case .past:
                if opening { showPast = true }
            }
        }
    }

    // MARK: - picture

    private func attach(_ item: PhotosPickerItem) async {
        defer { pickedItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let picked = UIImage(data: data) else { return }
        let image = PostImage(uiImage: picked.scaled(maxSide: 1400))
        withAnimation(.spring(duration: 0.5, bounce: 0.25)) { photo = image }
        // Focus the caption once the system picker has finished dismissing; before that it is ignored.
        try? await Task.sleep(for: .milliseconds(600))
        if mode == .picture { captionFocused = true }
    }

    /// The picture card: a gray polaroid you tap to choose a photo, which becomes your photo with a caption slip.
    /// The same card is the one peeking in from the side while you are on "write".
    private var pictureCard: some View {
        let side = Metrics.stickySide
        let height = photo.map(pictureFaceHeight) ?? side
        let width = photo.map { height * $0.pinAspect } ?? side
        let active = mode == .picture

        return VStack(spacing: -12) {
            ZStack {
                if let photo {
                    Image(uiImage: photo.uiImage).resizable().scaledToFill()
                } else {
                    Color(white: 0.871)                                  // #DEDEDE, the placeholder in the design
                        .overlay {
                            VStack(spacing: 8) {
                                Image("PhotoGlyph").frame(width: 24, height: 24)
                                Text("Choose a photo").font(Typo.pixel(14))
                            }
                            .foregroundStyle(.black.opacity(0.4))
                            .opacity(active ? 1 : 0)
                        }
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
            .overlay(alignment: .top) { if photo != nil { Pushpin().offset(y: 10) } }
            .contentShape(.rect)
            .onTapGesture {
                guard !isEditingPhoto else { return }          // the pinned picture stays as it is
                if active { showPicker = true } else { go(.picture, opening: true) }
            }
            .overlay(alignment: .topTrailing) {
                if active, photo != nil, !isEditingPhoto {
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { photo = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .padding(10)
                    .accessibilityLabel("Remove photo")
                }
            }
            .accessibilityLabel(photo == nil ? "Choose a photo" : "Your photo")
            .accessibilityAddTraits(.isButton)

            if active, photo != nil {
                TextField("Add a caption", text: $caption, axis: .vertical)
                    .lineLimit(1...2)                                // grows to two lines, then stops
                    .font(Typo.pixel(12))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .focused($captionFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(width: 214)
                    .background(.white)
                    .overlay(Rectangle().strokeBorder(.black.opacity(0.15), lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                    .transition(.opacity)
            }
        }
    }

    /// "From my posts": a stack of your pinned notes. Tap it to choose one as your answer.
    private var pastCard: some View {
        let side = Metrics.stickySide
        let active = mode == .past
        return ZStack {
            Color(white: 0.871)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "square.stack")
                            .font(.system(size: 22, weight: .regular))
                        Text("From my posts").font(Typo.pixel(14))
                    }
                    .foregroundStyle(.black.opacity(0.4))
                    .opacity(active ? 1 : 0)
                }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white, lineWidth: 2))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
        .contentShape(.rect)
        .onTapGesture { if active { focused = false; captionFocused = false; showPast = true } else { go(.past, opening: true) } }
        .accessibilityLabel("Choose from my posts")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - paper

    private var paper: some View {
        let padding = isPage
            ? EdgeInsets(top: 22, leading: 22, bottom: 18, trailing: 22)
            : EdgeInsets(top: 24, leading: 20, bottom: 20, trailing: 20)

        return VStack(alignment: .leading, spacing: 0) {
            if isPage {
                TextField("Title (optional)", text: $title)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(.black)
                    .padding(.bottom, 20)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Typo.body17)
                        .foregroundStyle(.black.opacity(0.28))
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(Typo.body17)
                    .lineSpacing(3)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding(.horizontal, -5)    // cancel TextEditor's built-in inset so text lines up
                    .padding(.vertical, -8)
            }
        }
        .padding(padding)
        .frame(width: paperSize.width, height: paperSize.height, alignment: .topLeading)
        .background(CutCornerShape(scale: Metrics.stickyScale).fill(stickyColor.body.mix(with: .white, by: whiteness)))
        .overlay(alignment: .bottomTrailing) {
            PaperFold()
                .fill(stickyColor.flap.mix(with: Color(white: 0.93), by: whiteness))
                .frame(width: 26.6 * Metrics.stickyScale, height: 26.6 * Metrics.stickyScale)
        }
        .clipShape(CutCornerShape(scale: Metrics.stickyScale))
        .keyframeAnimator(initialValue: Lift(), trigger: unfoldTrigger) { content, v in
            content
                .overlay(alignment: .top) {
                    CreaseShade()
                        .frame(height: 22)
                        .offset(y: 240)
                        .opacity(v.crease)
                        .allowsHitTesting(false)
                }
                .scaleEffect(v.scale)
                .rotationEffect(.degrees(v.rotation))
                .shadow(color: .black.opacity(v.shadowOpacity), radius: v.shadowRadius, y: v.shadowY)
        } keyframes: { _ in
            // 0.88s in total, shaped after the web prototype (crease-led: small lift, strong crease)
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.022, duration: 0.14)
                CubicKeyframe(1.0055, duration: 0.55)
                CubicKeyframe(1.0, duration: 0.19)
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(-0.7, duration: 0.14)
                CubicKeyframe(0.25, duration: 0.55)
                CubicKeyframe(-0.075, duration: 0.09)
                CubicKeyframe(0, duration: 0.10)
            }
            KeyframeTrack(\.shadowRadius) {
                CubicKeyframe(14, duration: 0.14)
                CubicKeyframe(9, duration: 0.55)
                CubicKeyframe(3, duration: 0.19)
            }
            KeyframeTrack(\.shadowY) {
                CubicKeyframe(9, duration: 0.14)
                CubicKeyframe(6, duration: 0.55)
                CubicKeyframe(2, duration: 0.19)
            }
            KeyframeTrack(\.shadowOpacity) {
                CubicKeyframe(0.17, duration: 0.14)
                CubicKeyframe(0.14, duration: 0.55)
                CubicKeyframe(0.12, duration: 0.19)
            }
            KeyframeTrack(\.crease) {
                CubicKeyframe(1, duration: 0.33)       // peaks as the first stage finishes
                CubicKeyframe(0, duration: 0.55)       // then smooths out
            }
        }
        .background(alignment: .topLeading) { heightProbe }
        .accessibilityElement(children: .contain)
    }

    /// Invisible copy of the text laid out at the sticky's width. A trailing zero-width character makes
    /// trailing newlines count, so pressing Enter a bunch of times fills the sticky like real lines do.
    private var heightProbe: some View {
        Text(text + "\u{200B}")
            .font(Typo.body17)
            .lineSpacing(3)
            .frame(width: Metrics.stickyInnerWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { textHeight = $0 }
            .accessibilityHidden(true)
    }

    private struct Lift {
        var scale = 1.0
        var rotation = 0.0
        var shadowRadius = 3.0
        var shadowY = 2.0
        var shadowOpacity = 0.12
        var crease = 0.0
    }

    // MARK: - sticky <-> page

    private func pageSize(stage: Int) -> CGSize {
        let w = min(Metrics.pageWidth, available.width - 40)
        // keep the page above the keyboard: it lives in the space the safe area leaves us
        let room = max(260, available.height - 36 - 50)
        let full = min(Metrics.pageHeight, room)
        return CGSize(width: w, height: stage == 1 ? min(Metrics.stage1Height, full) : full)
    }

    private func setPage(_ on: Bool) {
        morphTask?.cancel()
        if on {
            unfoldTrigger += 1
            // stage 1: wider and a little taller, colour starts to drain
            withAnimation(.spring(duration: 0.42, bounce: 0.12)) {
                isPage = true
                paperSize = pageSize(stage: 1)
                whiteness = 0.55
            }
            // stage 2: drops open
            morphTask = Task {
                try? await Task.sleep(for: .milliseconds(340))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.5, bounce: 0.1)) {
                    paperSize = pageSize(stage: 2)
                    whiteness = 1
                }
                try? await Task.sleep(for: .milliseconds(420))
                guard !Task.isCancelled else { return }
                landed += 1
            }
        } else {
            withAnimation(.spring(duration: 0.42, bounce: 0.15)) {
                isPage = false
                paperSize = CGSize(width: Metrics.stickyWidth, height: Metrics.stickyHeight)
                whiteness = 0
            }
        }
    }

    // MARK: - actions

    private func save() {
        guard let editing else { return }
        if isEditingPhoto { store.updateCaption(editing.id, caption: caption) }
        else { store.update(editing.id, title: title, body: text, asJournal: isPage, stickyColor: stickyColor) }
        dismiss()
    }

    private func post() {
        if mode == .picture, let photo {
            store.addPost(title: "", body: caption, dayID: dayID, asJournal: false, photo: photo)
        } else {
            store.addPost(title: title, body: text, dayID: dayID, asJournal: isPage, stickyColor: stickyColor)
        }
        dismiss()
    }
}

// MARK: - pieces

/// A color's nickname as a small tag in that color. Each time `bounce` changes it springs up from below with an overshoot.
private struct NameTag: View {
    let color: StickyColor
    let bounce: Int
    @State private var progress = 0.0

    var body: some View {
        Text(color.nickname)
            .font(Typo.pixel(12))
            .foregroundStyle(.black)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color.body, in: Capsule())
            .overlay(Capsule().strokeBorder(color.flap, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))     // a dotted outline
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            .rotationEffect(.degrees(-6 - 14 * (1 - progress)))                                         // sits a little askew
            .scaleEffect(0.45 + 0.55 * progress)
            .offset(y: -26 + 26 * (1 - progress))
            .opacity(min(1, progress * 3))
            .task(id: bounce) {
                var reset = Transaction(); reset.disablesAnimations = true
                withTransaction(reset) { progress = 0 }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.42)) { progress = 1 }
            }
    }
}

/// Where a page sits in the pager: centered when it is the current one, otherwise peeking in from its side
/// (earlier pages to the left, later ones to the right), smaller and tilted.
private struct PageSlot: ViewModifier {
    let mode: PostComposerView.PageMode
    let own: PostComposerView.PageMode
    let shift: CGFloat
    let peek: CGFloat
    let lift: CGFloat

    func body(content: Content) -> some View {
        let rel = own.rawValue - mode.rawValue          // -1 = one page to the left, 1 = one to the right
        content
            .scaleEffect(rel == 0 ? 1 : peek)
            .rotationEffect(.degrees(rel == 0 ? 0 : (rel < 0 ? 2.41 : -2.41)))
            .offset(x: CGFloat(rel) * shift, y: rel == 0 ? 0 : lift)
    }
}

/// The day marker (dotted line + pink dot) with the day label below. Tap the label to pick a past day.
/// When editing, the day is fixed and the label is plain text.
private struct DayHeader: View {
    @Environment(BoardStore.self) private var store
    @Binding var dayID: Int
    let isClip: Bool
    var editable = true

    var body: some View {
        VStack(spacing: 8) {
            // the same dot as the timeline: orange for today, gray for a past day
            ZStack(alignment: .top) {
                Path { p in
                    p.move(to: CGPoint(x: 4, y: 15.5)); p.addLine(to: CGPoint(x: 4, y: 30.5))
                    p.move(to: CGPoint(x: 4, y: 1.5)); p.addLine(to: CGPoint(x: 4, y: 2.3))
                    p.move(to: CGPoint(x: 4, y: 9.5)); p.addLine(to: CGPoint(x: 4, y: 8.7))
                }
                .stroke(.black.opacity(0.1), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Dot(isToday: dayID == store.todayID)
                    .frame(width: 8, height: 8)
                    .offset(y: 26.5)
            }
            .frame(width: 8, height: 34.5, alignment: .top)
            .accessibilityHidden(true)

            if editable {
                Menu {
                    Picker("Day", selection: $dayID) {
                        ForEach(store.postableDays, id: \.self) { id in
                            Text(id == store.todayID ? "\(store.fullLabel(id)) · today" : store.fullLabel(id)).tag(id)
                        }
                    }
                } label: {
                    label(showChevron: true)
                }
                .accessibilityLabel("Day: \(store.fullLabel(dayID))")
                .accessibilityHint("Pick a past day to clip this onto")
            } else {
                label(showChevron: false)
            }
        }
    }

    private func label(showChevron: Bool) -> some View {
        HStack(spacing: 6) {
            Text(store.fullLabel(dayID))
            if isClip {
                Image(systemName: "paperclip")
                    .foregroundStyle(Color("DayPink"))
                    .transition(.scale.combined(with: .opacity))
            }
            if showChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.35))
            }
        }
        .font(Typo.scaled(17, .medium, relativeTo: .body))
        .foregroundStyle(.black)
        .animation(.snappy, value: isClip)
    }
}

private struct CreaseShade: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [.black.opacity(0.10), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(.black.opacity(0.14)).frame(height: 1)
        }
    }
}
