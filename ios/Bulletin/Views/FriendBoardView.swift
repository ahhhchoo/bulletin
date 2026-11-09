import SwiftUI
import PhotosUI

/// A friend's board: their look, their days, and a dock at the bottom with a sticky note and a sticker.
/// Drag either one onto the board. A sticky note then asks what you want to say; a sticker just sticks.
struct FriendBoardView: View {
    @Environment(FriendsStore.self) private var store
    @Environment(StickerStore.self) private var stickers
    let friend: Friend
    var nextLabel: String?
    var onNext: (() -> Void)?
    let onClose: () -> Void
    /// True while you are dragging, writing, choosing a sticker or holding the board, so a queue waits for you.
    @Binding var busy: Bool

    private enum DragKind: Equatable { case note, sticker(Sticker) }
    private struct Drag { var kind: DragKind; var point: CGPoint }

    @State private var drag: Drag?
    @State private var contentFrame = CGRect.zero
    @State private var sheetTop: CGFloat = 0
    @State private var postFrames: [AnyHashable: CGRect] = [:]
    @State private var dockTop = CGFloat.infinity
    @State private var pendingNote: CGPoint?
    @State private var showTray = false
    @GestureState private var touching = false

    private var isBusy: Bool { drag != nil || pendingNote != nil || showTray || showAnswer || touching }
    private var days: [BoardDay] { store.boards[friend.id] ?? [] }
    private var items: [BoardItem] { store.items[friend.id] ?? [] }

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()
            VStack(spacing: 0) {
                header
                cards.padding(.top, 12)
                sheet.padding(.top, 17)
            }
            if let drag { ghost(drag).allowsHitTesting(false) }
            if let spot = pendingNote {
                NoteWriter(friend: friend.name,
                           onCancel: { withAnimation(.snappy) { pendingNote = nil } },
                           onSend: { text in
                               let id = withAnimation(.spring(duration: 0.45, bounce: 0.35)) { () -> BoardItem.ID in
                                   pendingNote = nil
                                   return store.place(.note(text), on: friend.id, at: spot)
                               }
                               settle(id, near: spot, size: Self.noteSize)
                           })
                .transition(.opacity)
            }
        }
        .coordinateSpace(name: "fb")
        .sheet(isPresented: $showTray) { StickerTray() }
        .onChange(of: isBusy) { _, v in busy = v }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: items.count)
    }

    // MARK: header and cards

    private var header: some View {
        HStack(spacing: 7) {
            Circle().fill(friend.color).frame(width: 28, height: 28)
            Text("\(friend.name)’s Bulletin").font(Typo.scaled(14, .medium, relativeTo: .subheadline))
            Spacer()
            if let nextLabel, let onNext {
                Button(action: onNext) {
                    Text(nextLabel).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7).background(.black, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 17, weight: .regular)).foregroundStyle(.black)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Close")
        }
        .padding(.leading, 25).padding(.trailing, 14).padding(.top, 8)
    }

    private var cards: some View {
        HStack(spacing: 8) {
            BigWord(label: "currently into", value: friend.into, size: 18)
                .frame(width: 152, height: 83, alignment: .leading)
                .background(Color("CardInto"), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            promptCard
        }
        .padding(.horizontal, 12)
    }

    @Environment(BoardStore.self) private var board
    @State private var showAnswer = false

    private var answerPost: Post? { days.flatMap(\.posts).first(where: \.isPromptAnswer) }

    /// Everyone gets the same prompt, written by the app. The friend's answer is their reply; tap it to read it in full.
    private var promptCard: some View {
        PromptChat(question: board.prompt, answer: answerPost, onAnswer: { showAnswer = true })
            .frame(maxWidth: .infinity)
            .frame(height: 83)
            .background(Color("CardPrompt"), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .popover(isPresented: $showAnswer, arrowEdge: .top) {
                if let post = answerPost {
                    PostView(post: post, animated: false, tilt: 0)
                        .padding(24)
                        .presentationCompactAdaptation(.popover)
                }
            }
    }

    // MARK: the board

    private var sheet: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                        DayBlock(day: day, isLast: i == days.count - 1, highlightNew: friend.hasNew && i == 0) { id, frame in postFrames[id] = frame }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 560, alignment: .topLeading)
                ForEach(items) { item in
                    ItemView(item: item) { store.take(item.id, from: friend.id) }
                        .position(item.position)
                        .transition(.scale(scale: 1.5).combined(with: .opacity))
                }
            }
            .coordinateSpace(name: "content")
            .padding(.bottom, 180)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("fb")) } action: { contentFrame = $0 }
        }
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("fb")).minY } action: { sheetTop = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0).updating($touching) { _, s, _ in s = true })
        .frame(maxWidth: .infinity)
        .background(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
            .fill(.white).ignoresSafeArea(edges: .bottom))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
        .overlay(alignment: .bottom) { dock }
    }

    // MARK: dock

    private var dock: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 64) {
                NoteTile()
                    .gesture(dragGesture(.note))
                    .onTapGesture { withAnimation(.snappy) { pendingNote = CGPoint(x: 150, y: 340) } }
                    .accessibilityLabel("Sticky note")
                    .accessibilityHint("Drag onto the board, or tap to write a note")
                    .opacity(drag?.kind == .note ? 0.35 : 1)
                StickerView(sticker: stickers.selected, size: 62)
                    .gesture(dragGesture(.sticker(stickers.selected)))
                    .onTapGesture { showTray = true }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "chevron.up.circle.fill").font(.system(size: 16))
                            .foregroundStyle(.black.opacity(0.35), .white).offset(x: 8, y: -6)
                    }
                    .accessibilityLabel("Sticker")
                    .accessibilityHint("Drag onto the board, or tap to choose a sticker")
                    .opacity(drag?.kind == .sticker(stickers.selected) ? 0.35 : 1)
            }
            Text("Add to \(friend.name)’s bulletin")
                .font(Typo.scaled(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(.black.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 54).padding(.bottom, 26)
        .background(LinearGradient(colors: [.white.opacity(0), .white, .white], startPoint: .top, endPoint: .bottom))
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("fb")).minY } action: { dockTop = $0 }
    }

    private func dragGesture(_ kind: DragKind) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("fb"))
            .onChanged { v in drag = Drag(kind: kind, point: v.location) }
            .onEnded { v in
                let p = v.location
                withAnimation(.snappy) { drag = nil }
                // Let go over the dock and it springs back. Let go over the board and it sticks there.
                // Dropping on the masthead cards or back on the dock doesn't place it.
                guard p.y < dockTop - 8, p.y > sheetTop + 8 else { return }
                let spot = CGPoint(x: p.x - contentFrame.minX, y: p.y - contentFrame.minY)
                switch kind {
                case .note: withAnimation(.snappy) { pendingNote = spot }
                case .sticker(let s):
                    let id = withAnimation(.spring(duration: 0.45, bounce: 0.4)) { store.place(.sticker(s), on: friend.id, at: spot) }
                    settle(id, near: spot, size: Self.stickerSize)
                }
            }
    }

    // MARK: keeping the board readable

    static let noteSize = CGSize(width: 124, height: 104)
    static let stickerSize = CGSize(width: 80, height: 80)

    /// Things stuck on a board must not cover what's already there. If it lands on a post (or a note),
    /// it slides to the nearest free spot beside it, though a small overlap on a post's edge is allowed.
    private func settle(_ id: BoardItem.ID, near spot: CGPoint, size: CGSize) {
        // A little overlap on a post's top and side edges is fine (stickers like to sit on corners).
        // The bottom edge stays clear, since that is where a photo's caption slip sits.
        let edge: CGFloat = 14
        // (day labels and "its kinda empty..." are in here too, and those get no overlap)
        var blocked = postFrames.map { key, f -> CGRect in
            if let k = key.base as? String, k.hasPrefix("label") || k.hasPrefix("empty") { return f.insetBy(dx: -4, dy: -2) }
            return CGRect(x: f.minX + edge, y: f.minY + edge, width: max(0, f.width - edge * 2), height: max(0, f.height - edge))
        }
        for other in items where other.id != id {
            if case .note = other.kind {
                blocked.append(CGRect(x: other.position.x - Self.noteSize.width / 2, y: other.position.y - Self.noteSize.height / 2,
                                      width: Self.noteSize.width, height: Self.noteSize.height))
            }
        }
        let target = FriendBoardView.freeSpot(near: spot, size: size, avoiding: blocked, width: contentFrame.width)
        guard target != spot else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { store.move(id, on: friend.id, to: target) }
        }
    }

    static func freeSpot(near p: CGPoint, size: CGSize, avoiding blocked: [CGRect], width: CGFloat) -> CGPoint {
        let halfW = size.width / 2, halfH = size.height / 2
        func clamp(_ c: CGPoint) -> CGPoint {
            CGPoint(x: min(max(c.x, 50 + halfW), max(50 + halfW, width - 8 - halfW)), y: max(c.y, 48 + halfH))
        }
        func free(_ c: CGPoint) -> Bool {
            let r = CGRect(x: c.x - halfW, y: c.y - halfH, width: size.width, height: size.height)
            return !blocked.contains { $0.intersects(r) }
        }
        let start = clamp(p)
        if free(start) { return start }
        let gap: CGFloat = 6
        var best: CGPoint?, bestDistance = CGFloat.infinity
        for o in blocked {
            let tries = [
                CGPoint(x: o.maxX + gap + halfW, y: start.y), CGPoint(x: o.minX - gap - halfW, y: start.y),
                CGPoint(x: start.x, y: o.maxY + gap + halfH), CGPoint(x: start.x, y: o.minY - gap - halfH),
            ]
            for t in tries {
                let c = clamp(t)
                let d = hypot(c.x - start.x, c.y - start.y)
                if free(c), d < bestDistance { best = c; bestDistance = d }
            }
        }
        if let best { return best }
        // crowded: go below everything
        let bottom = blocked.map(\.maxY).max() ?? start.y
        return clamp(CGPoint(x: start.x, y: bottom + gap + halfH))
    }

    @ViewBuilder private func ghost(_ d: Drag) -> some View {
        Group {
            switch d.kind {
            case .note: NoteTile(size: 96)
            case .sticker(let s): StickerView(sticker: s, size: 84)
            }
        }
        .scaleEffect(1.08)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 8)
        .position(d.point)
    }
}

// MARK: - Pieces

private struct DayBlock: View {
    @Environment(BoardStore.self) private var board
    let day: BoardDay
    let isLast: Bool
    let highlightNew: Bool
    let onFrame: (AnyHashable, CGRect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(board.shortLabel(day.id))
                .font(Typo.scaled(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.black.opacity(0.5)).frame(height: 17)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("content")) } action: { onFrame("label-\(day.id)", $0) }
            if day.posts.isEmpty {
                Text("its kinda empty...")
                    .font(Typo.scaled(14, .regular, relativeTo: .subheadline).italic())
                    .foregroundStyle(.black.opacity(0.5)).padding(.top, 5)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("content")) } action: { onFrame("empty-\(day.id)", $0) }
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(day.posts) { post in
                        PostView(post: post, animated: false)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("content")) } action: { onFrame(post.id, $0) }
                            .overlay(alignment: .topTrailing) {
                                if highlightNew {
                                    Text("new").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Color("DayPink"), in: Capsule()).offset(x: 6, y: -4)
                                }
                            }
                    }
                }
                .padding(.top, 18).padding(.leading, 6)
            }
        }
        .padding(.leading, 44)
        .padding(.bottom, isLast ? 0 : 41)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) { Circle().fill(.black).frame(width: 8, height: 8).offset(x: 25, y: 4.5) }
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle().fill(.black.opacity(0.1)).frame(width: 3)
                    .padding(.top, 8.5).padding(.bottom, -28.5).offset(x: 27.5)
            }
        }
        .padding(.top, 20)
    }
}

/// The sticky note in the dock: a tilted green square with a plus.
private struct NoteTile: View {
    var size: CGFloat = 52
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color("Sticky"))
            .frame(width: size, height: size)
            .overlay(Image(systemName: "plus").font(.system(size: size * 0.5, weight: .medium)).foregroundStyle(.black.opacity(0.35)))
            .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
            .rotationEffect(.degrees(8))
            .frame(width: size + 14, height: size + 14)
    }
}

private struct ItemView: View {
    let item: BoardItem
    let takeBack: () -> Void

    var body: some View {
        Group {
            switch item.kind {
            case .note(let text):
                Text(text)
                    .font(Typo.pixel(12))
                    .foregroundStyle(.black)
                    .frame(width: 96, alignment: .leading)
                    .frame(minHeight: 60, alignment: .topLeading)
                    .padding(.horizontal, 10).padding(.top, 16).padding(.bottom, 10)
                    .background(Color("Sticky"), in: RoundedRectangle(cornerRadius: 3))
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
                    .overlay(alignment: .top) { Pushpin().offset(y: -4) }
            case .sticker(let s):
                StickerView(sticker: s, size: 72)
            }
        }
        .rotationEffect(.degrees(item.rotation))
        .contextMenu {
            if item.mine { Button("Take back", systemImage: "arrow.uturn.backward", role: .destructive, action: takeBack) }
        }
    }
}

/// Where you write the note, over a dimmed board. Sending drops it where you let go.
private struct NoteWriter: View {
    let friend: String
    let onCancel: () -> Void
    let onSend: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    private let limit = 140

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.28).ignoresSafeArea().onTapGesture { focused = false }
            VStack(spacing: 16) {
                TextField("Write something to \(friend)…", text: $text, axis: .vertical)
                    .focused($focused)
                    .font(Typo.pixel(15))
                    .lineLimit(3...6)
                    .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 16)
                    .frame(width: 240, alignment: .topLeading)
                    .frame(minHeight: 170, alignment: .topLeading)
                    .background(Color("Sticky"), in: RoundedRectangle(cornerRadius: 3))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 4)
                    .overlay(alignment: .top) { Pushpin().offset(y: -4) }
                    .rotationEffect(.degrees(-2))
                    .onChange(of: text) { _, new in if new.count > limit { text = String(new.prefix(limit)) } }
                HStack(spacing: 10) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18).padding(.vertical, 10).background(.white, in: Capsule())
                    Button("Stick it") { onSend(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 10).background(.black, in: Capsule())
                        .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 1)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(PressableStyle())
            }
            .padding(.top, 90)
        }
        .onAppear { focused = true }
    }
}

// MARK: - Stickers

struct StickerView: View {
    let sticker: Sticker
    var size: CGFloat = 72

    var body: some View {
        Group {
            if let image = sticker.image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let symbol = sticker.symbol {
                ZStack {
                    // a white edge, like a die-cut sticker
                    Image(systemName: symbol).font(.system(size: size * 0.7, weight: .black))
                        .foregroundStyle(.white).scaleEffect(1.22)
                    Image(systemName: symbol).font(.system(size: size * 0.7, weight: .black))
                        .foregroundStyle(sticker.tint ?? .black)
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
    }
}

/// Pick which sticker is in the dock, or make a new one from a photo.
private struct StickerTray: View {
    @Environment(StickerStore.self) private var stickers
    @Environment(\.dismiss) private var dismiss
    @State private var pick: PhotosPickerItem?
    @State private var making = false
    @State private var errorText: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Stickers").font(.system(size: 22, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }.font(.system(size: 16, weight: .semibold))
            }
            PhotosPicker(selection: $pick, matching: .images) {
                HStack(spacing: 10) {
                    if making { ProgressView() } else { Image(systemName: "person.crop.circle.badge.plus") }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Make one from a photo").font(.system(size: 15, weight: .semibold))
                        Text("We’ll lift the person or thing out for you").font(.footnote).foregroundStyle(.black.opacity(0.5))
                    }
                    Spacer()
                }
                .foregroundStyle(.black)
                .padding(14)
                .background(Color("CardPrompt"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(making)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(stickers.all) { s in
                        Button { stickers.selected = s; dismiss() } label: {
                            StickerView(sticker: s, size: 56)
                                .frame(maxWidth: .infinity).frame(height: 76)
                                .background(.black.opacity(stickers.selected == s ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.black.opacity(stickers.selected == s ? 0.5 : 0), lineWidth: 1.5))
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            if s.isMine { Button("Delete", systemImage: "trash", role: .destructive) { stickers.remove(s) } }
                        }
                    }
                }
            }
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationBackground(.white)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            making = true
            Task {
                defer { making = false; pick = nil }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw StickerMaker.Failure.unreadable }
                    let cut = try await StickerMaker.cutout(from: data)
                    stickers.add(cutout: cut)
                } catch {
                    errorText = (error as? LocalizedError)?.errorDescription ?? "Couldn’t make a sticker from that photo."
                }
            }
        }
        .alert("No sticker", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorText ?? "") }
    }
}
