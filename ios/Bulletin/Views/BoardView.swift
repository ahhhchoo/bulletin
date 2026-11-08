import SwiftUI

/// BRD-01 Board / today
struct BoardView: View {
    @Environment(BoardStore.self) private var store
    @State private var showComposer = false

    var body: some View {
        ZStack(alignment: .top) {
            Color("Backdrop").ignoresSafeArea()

            VStack(spacing: 8) {
                HeaderView()
                BoardSheet()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ComposerPill { showComposer = true }
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showComposer, onDismiss: { store.answeringPrompt = false }) {
            PostComposerView(todayID: store.todayID)
        }
        .onChange(of: store.answeringPrompt) { _, answering in
            if answering { showComposer = true }
        }
    }
}

// MARK: - Header

private struct HeaderView: View {
    @Environment(BoardStore.self) private var store
    @State private var page: Int? = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("My November")
                .font(Typo.scaled(24, .medium, relativeTo: .title))
                .padding(.leading, 28)
                .padding(.top, 15)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 5) {
                    HeaderCard(background: "CardInto", tag: 0) {
                        CardText(label: "currently into:", value: store.currentlyInto)
                    }
                    HeaderCard(background: "CardPrompt", tag: 1) {
                        PromptCardContent()
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page)
            .contentMargins(.horizontal, 27, for: .scrollContent)
            .frame(height: 76)
            .padding(.top, 15)

            PageDots(current: page ?? 0, count: 2)
                .frame(maxWidth: .infinity)
                .padding(.top, 11)
                .padding(.bottom, 17)
        }
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("Paper"))
                .ignoresSafeArea(edges: .top)
        }
    }
}

private struct HeaderCard<Content: View>: View {
    let background: String
    let tag: Int
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(background), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .containerRelativeFrame(.horizontal) { length, _ in length - 54 }
            .id(tag)
    }
}

private struct CardText: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).foregroundStyle(.black.opacity(0.5))
            Text(value).foregroundStyle(.black)
        }
        .font(Typo.scaled(14, .medium, relativeTo: .subheadline))
        .padding(.leading, 20)
    }
}

private struct PromptCardContent: View {
    @Environment(BoardStore.self) private var store

    var body: some View {
        HStack {
            CardText(label: "this month's prompt:", value: store.prompt)
            Spacer(minLength: 0)
            PromptButton()
                .padding(.trailing, 16)
        }
    }
}

private struct PromptButton: View {
    @Environment(BoardStore.self) private var store

    var body: some View {
        let answered = store.promptAnswerID != nil
        Button {
            guard !answered else { return }
            withAnimation(.snappy) { store.answeringPrompt = true }
        } label: {
            ZStack {
                if answered {
                    Circle().fill(Color("Sticky"))
                    Text("Tue 3").font(.system(size: 11, weight: .medium))
                } else {
                    Circle()
                        .strokeBorder(.black.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }
            .frame(width: 40, height: 40)
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(answered ? "Prompt answered" : "Answer the prompt")
    }
}

private struct PageDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(.black.opacity(i == current ? 0.2 : 0.1))
                    .frame(width: i == current ? 16 : 7, height: 7)
            }
        }
        .animation(.snappy(duration: 0.25), value: current)
        .accessibilityHidden(true)
    }
}

// MARK: - Board sheet

private struct BoardSheet: View {
    @Environment(BoardStore.self) private var store

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.days) { day in
                        DayRow(day: day, isLast: day.id == store.days.last?.id)
                            .id("day-\(day.id)")
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, 150, for: .scrollContent)   // lets the last day scroll up above the pill and tab bar
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
                    .fill(Color("Paper"))
                    .ignoresSafeArea(edges: .bottom)
            )
            .onChange(of: store.postCount) {
                // Show the day the post landed on, label at the top (works for clipped posts on past days too).
                guard let day = store.lastPostedDayID else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))   // let the composer sheet finish dismissing
                    withAnimation(.smooth(duration: 0.55)) { proxy.scrollTo("day-\(day)", anchor: .top) }
                }
            }
        }
    }
}

private struct DayRow: View {
    @Environment(BoardStore.self) private var store
    let day: BoardDay
    let isLast: Bool

    private let gutter: CGFloat = 44
    private let dot: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(store.shortLabel(day.id))
                .font(Typo.scaled(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.black.opacity(0.5))
                .frame(height: 17)

            if day.posts.isEmpty {
                Text("its kinda empty...")
                    .font(Typo.scaled(14, .regular, relativeTo: .subheadline).italic())
                    .foregroundStyle(.black.opacity(0.5))
                    .padding(.top, 5)
                    .transition(.opacity)
            } else {
                PostsGrid(posts: day.posts)
                    .padding(.top, 18)
            }
        }
        .padding(.leading, gutter)
        .padding(.bottom, isLast ? 0 : 41)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) { Dot().frame(width: dot, height: dot).offset(x: 25, y: 4.5) }
        .background(alignment: .topLeading) {
            if !isLast {
                // the timeline: from this dot's center down to the next dot's center
                Rectangle()
                    .fill(.black.opacity(0.1))
                    .frame(width: 3)
                    .padding(.top, 8.5)
                    .padding(.bottom, -28.5)   // reaches the next dot, past its 20pt top cushion
                    .offset(x: 27.5)
            }
        }
        .animation(.smooth, value: day.posts.isEmpty)
        .padding(.top, 20)   // cushion above the label, so scrollTo(day, anchor: .top) isn't flush with the sheet edge
    }
}

private struct Dot: View {
    var body: some View { Circle().fill(.black) }
}

private struct PostsGrid: View {
    let posts: [Post]

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 132, maximum: 160), spacing: 18, alignment: .top)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
            ForEach(posts) { post in
                PostView(post: post)
                    .id(post.id)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 24)
    }
}
