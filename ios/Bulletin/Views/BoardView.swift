import SwiftUI

/// BRD-01 Board / today
struct BoardView: View {
    @Environment(BoardStore.self) private var store

    var body: some View {
        ZStack(alignment: .top) {
            Color("Backdrop").ignoresSafeArea()

            VStack(spacing: 8) {
                HeaderView()
                BoardSheet()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ComposerView()
                .padding(.bottom, 8)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: store.postCount)
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
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
                    .fill(Color("Paper"))
                    .ignoresSafeArea(edges: .bottom)
            )
            .onChange(of: store.postCount) {
                guard let last = store.days.last?.posts.last else { return }
                withAnimation(.smooth) { proxy.scrollTo(last.id, anchor: .center) }
            }
        }
    }
}

private struct DayRow: View {
    let day: BoardDay
    let isLast: Bool

    private let gutter: CGFloat = 44
    private let dot: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(day.label)
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
        .padding(.bottom, isLast ? 0 : 61)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) { Dot().frame(width: dot, height: dot).offset(x: 25, y: 4.5) }
        .background(alignment: .topLeading) {
            if !isLast {
                // the timeline: from this dot's center down to the next dot's center
                Rectangle()
                    .fill(.black.opacity(0.1))
                    .frame(width: 3)
                    .padding(.top, 8.5)
                    .padding(.bottom, -8.5)
                    .offset(x: 27.5)
            }
        }
        .animation(.smooth, value: day.posts.isEmpty)
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
