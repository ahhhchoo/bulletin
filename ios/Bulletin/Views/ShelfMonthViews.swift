import SwiftUI

/// Name a month and pick its cover photo from that month. Used when a month is sealed and later, to rename it.
struct NameMonthView: View {
    let heading: String
    /// The month's photos, to choose a cover from.
    let photos: [PostImage]
    var saveLabel = "Save"
    /// What the month shows now when no cover has been picked.
    var fallback: UIImage?
    /// Sealing only: skip naming and seal with the defaults.
    var onSkip: (() -> Void)?
    let onSave: (String, PostImage?) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var cover: PostImage?
    @FocusState private var focused: Bool

    static let titleLimit = 30

    init(heading: String, photos: [PostImage], title: String = "", cover: PostImage? = nil, saveLabel: String = "Save", fallback: UIImage? = nil,
         onSkip: (() -> Void)? = nil, onSave: @escaping (String, PostImage?) -> Void, onCancel: @escaping () -> Void) {
        self.heading = heading
        self.photos = photos
        self.saveLabel = saveLabel
        self.fallback = fallback
        self.onSkip = onSkip
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: title)
        _cover = State(initialValue: cover)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Text(heading)
                        .font(.system(size: 26, weight: .heavy)).tracking(-0.8)
                        .padding(.top, 62)

                    preview.padding(.top, 26)

                    TextField("", text: $title, prompt: Text("the month of…").foregroundStyle(.black.opacity(0.28)))
                        .font(.system(size: 22, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .submitLabel(.done)
                        .padding(.horizontal, 28).padding(.top, 22)
                        .onChange(of: title) { _, t in
                            if t.count > Self.titleLimit { title = String(t.prefix(Self.titleLimit)) }
                        }
                        .accessibilityLabel("Month title")
                    Text("\(title.count)/\(Self.titleLimit)")
                        .font(Typo.pixel(11)).foregroundStyle(.black.opacity(0.3)).padding(.top, 4)

                    coverPicker.padding(.top, 28)
                }
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(.white, in: Circle())
                        .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 22).padding(.top, 10)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Button { onSave(title, cover) } label: { CapsuleLabel(title: saveLabel, style: .solid) }
                    .buttonStyle(PressableStyle())
                if let onSkip {
                    Button("Skip", action: onSkip)
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(.black.opacity(0.5))
                        .frame(height: 30)
                }
            }
            .padding(.horizontal, 27).padding(.top, 8).padding(.bottom, 12)
            .background(Color("Paper"))
        }
    }

    /// The cover as it will sit on the shelf: tipped, like it was just set down.
    private var preview: some View {
        Group {
            if let shown = cover?.uiImage ?? fallback {
                Image(uiImage: shown).resizable().scaledToFill()
            } else {
                Color.black.opacity(0.06)
                    .overlay(Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(.black.opacity(0.25)))
            }
        }
        .frame(width: 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
        .rotationEffect(.degrees(-6))
        .animation(.snappy(duration: 0.25), value: cover)
    }

    @ViewBuilder private var coverPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a photo from this month")
                .font(Typo.pixel(13)).foregroundStyle(.black.opacity(0.55))
                .padding(.horizontal, 24)
            if photos.isEmpty {
                Text("No photos this month.")
                    .font(.system(size: 14)).foregroundStyle(.black.opacity(0.4))
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            let picked = cover == photo
                            Button { cover = picked ? nil : photo } label: {
                                Image(uiImage: photo.uiImage).resizable().scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(.black, lineWidth: picked ? 3 : 0))
                                    .opacity(cover == nil || picked ? 1 : 0.55)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(picked ? "Cover photo, selected" : "Use as cover photo")
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A sealed month, opened: its board as it was, read only. Tap a post to open it.
struct MonthBoardView: View {
    let month: ShelfMonth
    let onClose: () -> Void
    @State private var openPost: Post?

    private func label(_ day: Int) -> String { "\(month.short) \(day)" }

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(month.full) 20\(month.year)")
                            .font(.system(size: 30, weight: .heavy)).tracking(-1)
                        if !month.title.isEmpty {
                            Text(month.title).font(Typo.pixel(13)).foregroundStyle(.black.opacity(0.55))
                        }
                    }
                    .padding(.leading, 25).padding(.top, 70).padding(.bottom, 8)

                    if month.days.isEmpty && month.monthKey != nil && month.pins > 0 {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if month.days.isEmpty {
                        Text("Nothing was pinned this month.")
                            .font(.system(size: 15)).foregroundStyle(.black.opacity(0.45))
                            .padding(.leading, 25).padding(.top, 20)
                    }
                    ForEach(Array(month.days.enumerated()), id: \.element.id) { i, day in
                        DayBlock(day: day, isLast: i == month.days.count - 1, label: label) { post in
                            withAnimation(.snappy) { openPost = post }
                        }
                    }
                }
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)

            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(.white, in: Circle())
                        .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 22).padding(.top, 10)

            if let post = openPost {
                PostDetailView(post: post, origin: nil,
                               dayLabel: month.days.first { $0.posts.contains { $0.id == post.id } }.map { label($0.id) },
                               owner: true, friendName: "") {
                    openPost = nil
                }
                .transition(.opacity)
            }
        }
    }
}
