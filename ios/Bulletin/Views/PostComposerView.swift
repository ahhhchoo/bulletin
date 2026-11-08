import SwiftUI

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
    @FocusState private var focused: Bool

    // paper state
    @State private var isPage = false
    @State private var paperSize = CGSize(width: Metrics.stickySide, height: Metrics.stickySide)
    @State private var whiteness = 0.0              // 0 = sticky green, 1 = white page
    @State private var unfoldTrigger = 0            // fires the lift / crease keyframes
    @State private var landed = 0                   // fires the soft haptic when the page lands
    @State private var morphTask: Task<Void, Never>?
    @State private var available = CGSize(width: 402, height: 600)

    init(todayID: Int) { _dayID = State(initialValue: todayID) }

    private enum Metrics {
        static let stickySide: CGFloat = 246
        static let pageWidth: CGFloat = 362
        static let pageHeight: CGFloat = 485
        static let switchToPageAt = 220             // characters; tuned in the prototype
        static let switchBackBelow = 205
        static let stage1Height: CGFloat = 270      // crease-led: first stage is shallow
    }

    private var isClip: Bool { dayID != store.todayID }
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var placeholder: String {
        if store.answeringPrompt { return "answer the prompt…" }
        return isClip ? "add to \(store.shortLabel(dayID))…" : "What’s on your mind?"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DayHeader(dayID: $dayID, isClip: isClip)
                    .padding(.top, 2)

                paper
                    .padding(.top, 36)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .background(Color("Paper"))
            .onGeometryChange(for: CGSize.self, of: \.size) { available = $0 }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isClip ? "Clip" : "Pin", action: post)
                        .fontWeight(.semibold)
                        .disabled(trimmed.isEmpty)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { PhotoChip() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color("Paper"))
        .tint(.black)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: landed)
        .sensoryFeedback(.success, trigger: store.postCount)
        .onAppear { focused = true }
        .onChange(of: text) { _, new in
            let n = new.trimmingCharacters(in: .whitespacesAndNewlines).count
            if !isPage && n >= Metrics.switchToPageAt { setPage(true) }
            else if isPage && n < Metrics.switchBackBelow { setPage(false) }
        }
    }

    // MARK: - paper

    private var paper: some View {
        let padding = isPage
            ? EdgeInsets(top: 22, leading: 22, bottom: 18, trailing: 22)
            : EdgeInsets(top: 16, leading: 18, bottom: 18, trailing: 18)

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
        .background(Color("Sticky").mix(with: .white, by: whiteness))
        .clipShape(RoundedRectangle(cornerRadius: 2))
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
        .accessibilityElement(children: .contain)
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
                paperSize = CGSize(width: Metrics.stickySide, height: Metrics.stickySide)
                whiteness = 0
            }
        }
    }

    // MARK: - actions

    private func post() {
        store.addPost(title: title, body: text, dayID: dayID, asJournal: isPage)
        dismiss()
    }
}

// MARK: - pieces

/// The day marker (dotted line + pink dot) with the day label below. Tap the label to pick a past day.
private struct DayHeader: View {
    @Environment(BoardStore.self) private var store
    @Binding var dayID: Int
    let isClip: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image("DayMarker")
                .accessibilityHidden(true)

            Menu {
                Picker("Day", selection: $dayID) {
                    ForEach(store.postableDays, id: \.self) { id in
                        Text(id == store.todayID ? "\(store.fullLabel(id)) · today" : store.fullLabel(id)).tag(id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(store.fullLabel(dayID))
                    if isClip {
                        Image(systemName: "paperclip")
                            .foregroundStyle(Color("DayPink"))
                            .transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.35))
                }
                .font(Typo.scaled(17, .medium, relativeTo: .body))
                .foregroundStyle(.black)
                .animation(.snappy, value: isClip)
            }
            .accessibilityLabel("Day: \(store.fullLabel(dayID))")
            .accessibilityHint("Pick a past day to clip this onto")
        }
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

private struct PhotoChip: View {
    var body: some View {
        HStack {
            Button {
                // TODO: photo picker (v1 has one photo per post)
            } label: {
                HStack(spacing: 10) {
                    Image("PhotoGlyph").frame(width: 24, height: 24)
                    Text("Photo").font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(10)
                .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}
