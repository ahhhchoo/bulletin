import SwiftUI

private let cardGray = Color.white
private let inkSoft = Color.black.opacity(0.5)
private let seenGray = Color(white: 0.914)          // #E9E9E9: a block you have already opened
private let unseenBlue = Color(red: 0, green: 0.471, blue: 0.988)   // #0078FC

struct FriendsView: View {
    @Environment(FriendsStore.self) private var friends
    @State private var queue: QueueRequest?
    @State private var showGuests = false

    private let columns = [GridItem(.flexible(), spacing: 17), GridItem(.flexible(), spacing: 17)]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 19) {
                    LazyVGrid(columns: columns, spacing: 19) {
                        ForEach(friends.ordered) { friend in
                            FriendBlock(friend: friend) { open(startingAt: friend) }
                        }
                    }
                    .animation(.snappy, value: friends.ordered)
                }
                .padding(.horizontal, 15.5)
                .padding(.top, 113)
                .padding(.bottom, 130)
            }
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
            .background(Color("Paper"))
            .fullScreenCover(isPresented: $showGuests) { GuestsPage() }
            .overlay(alignment: .top) {
                header { showGuests = true }
            }
        }
        .animation(.snappy, value: friends.addBack)
        .fullScreenCover(item: $queue) { request in
            FriendQueueView(request: request) { queue = nil }
        }

    }

    /// "Shared" and, on the right, a person icon that jumps down to the guest list. It carries a blue dot while someone
    /// has put you on their list and you have not answered yet.
    private func header(toGuests: @escaping () -> Void) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(stops: [.init(color: Color("Paper"), location: 0.78), .init(color: Color("Paper").opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 112)
                .allowsHitTesting(false)
            Text("Shared").font(.system(size: 26, weight: .bold))
                .padding(.leading, 16).padding(.top, 57)
                .allowsHitTesting(false)
            Button(action: toGuests) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topTrailing) {
                        if friends.needsAttention {
                            Circle().fill(unseenBlue)
                                .overlay(Circle().strokeBorder(Color("Paper"), lineWidth: 1.5))
                                .frame(width: 12, height: 12)
                                .offset(x: -5, y: 5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 16).padding(.top, 53)
            .accessibilityLabel(friends.needsAttention ? "Guests, something new" : "Guests")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .ignoresSafeArea(edges: .top)
    }

    /// Tap a block: the boards with news, in order, starting on that friend. A friend with nothing new: just their board.
    private func open(startingAt first: Friend?) {
        var list = friends.withNews
        if let first, !first.hasNew { queue = QueueRequest(who: [first], auto: false); return }
        guard !list.isEmpty else { return }
        if let first, let i = list.firstIndex(of: first) { list.move(fromOffsets: [i], toOffset: 0) }
        queue = QueueRequest(who: list, auto: true)
    }
}

// MARK: - A friend's block

/// Their name, the last thing they posted, and when. White with a blue dot until you open their bulletin; gray after.
private struct FriendBlock: View {
    @Environment(FriendsStore.self) private var store
    let friend: Friend
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            ZStack(alignment: .topLeading) {
                Text(friend.name)
                    .font(Typo.pixel(14))
                    .foregroundStyle(friend.hasNew ? .black : .black.opacity(0.5))
                    .padding(.leading, 12).padding(.top, 10)
                preview.background { stackLayers }.padding(.top, 37).frame(maxWidth: .infinity)
                Text(friend.lastPosted.postStamp)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black.opacity(0.2))
                    .padding(.leading, 10).padding(.top, 214)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 235, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(friend.hasNew ? Color.white : seenGray)
                    .shadow(color: .black.opacity(friend.hasNew ? 0.1 : 0), radius: 2, y: 2)
            }
            .overlay(alignment: .topTrailing) {
                if friend.hasNew {
                    Circle().fill(unseenBlue)
                        .overlay(Circle().strokeBorder(Color("Paper"), lineWidth: 1))
                        .frame(width: 12, height: 12)
                        .offset(x: 3.5, y: -3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PressableStyle())
        .animation(.snappy, value: friend.hasNew)
        .accessibilityLabel(friend.hasNew ? "\(friend.name), has something new" : friend.name)
    }

    /// More than one post in their newest day: paper peeking out from behind, like a stacked essay.
    @ViewBuilder private var stackLayers: some View {
        let extra = min(2, max(0, store.latestDayCount(of: friend) - 1))
        ZStack {
            ForEach(0..<extra, id: \.self) { i in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.06))      // one color for every stack: #000000 at 6%
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.black.opacity(0.1), lineWidth: 1))
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    .scaleEffect(1 - CGFloat(i + 1) * 0.04)          // narrower each step, so only a sliver shows underneath, like a deck
                    .rotationEffect(.degrees(i == 0 ? 1.5 : -1.5))
                    .offset(y: CGFloat(9 + i * 8))
            }
        }
    }

    @ViewBuilder private var preview: some View {
        if let post = store.latestPost(of: friend) {
            switch post.kind {
            case .sticky(let text):
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .frame(width: 114, height: 128, alignment: .topLeading)
                    .padding(.horizontal, 13).padding(.vertical, 16)
                    .frame(width: Paper.width, height: Paper.minHeight, alignment: .topLeading)
                    .background(CutCornerShape().fill(post.stickyColor.body))
                    .overlay(alignment: .bottomTrailing) { PaperFold().fill(post.stickyColor.flap).frame(width: 26.6, height: 26.6) }
            default:
                if let image = post.image {
                    Image(uiImage: image.uiImage)
                        .resizable().scaledToFill()
                        .frame(width: 128, height: min(160, 128 / max(image.aspect, 0.01)))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                                        }
            }
        }
    }
}

// MARK: - Guests

/// A person on the guest list: a soft color where their picture goes.
struct Face: View {
    var color: Color = Color(white: 0.851)          // #D9D9D9
    var body: some View {
        Circle().fill(color)
            .frame(width: 32, height: 32)
            .overlay(Circle().strokeBorder(Color("Paper"), lineWidth: 2))
    }
}

// MARK: - Queue

/// What the full-screen cover opens on: the boards with news (one after another), or a single board.
private struct QueueRequest: Identifiable {
    let id = UUID()
    let who: [Friend]
    /// A queue plays through on its own; a single board you opened just stays.
    let auto: Bool
}

/// Only the boards with news, one at a time. Each plays for a while then moves on; touch the board to pause.
private struct FriendQueueView: View {
    @Environment(FriendsStore.self) private var store
    let request: QueueRequest
    let close: () -> Void

    private static let seconds = 12.0
    @State private var index = 0
    @State private var progress = 0.0
    @State private var busy = false
    @State private var topDim = 0.0
    @State private var finished = false
    private let tick = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    private var who: [Friend] { request.who }

    var body: some View {
        ZStack {
            Color("Paper").ignoresSafeArea()
            if finished { caughtUp } else { player }
        }
        .onReceive(tick) { _ in
            guard request.auto, !finished, !busy else { return }
            progress += (1.0 / 30) / Self.seconds
            if progress >= 1 { next() }
        }
    }

    private var player: some View {
        VStack(spacing: 0) {
            if request.auto {
                HStack(spacing: 5) {
                    ForEach(who.indices, id: \.self) { i in
                        Capsule().fill(.black.opacity(0.12)).frame(height: 4)
                            .overlay(alignment: .leading) {
                                GeometryReader { g in
                                    Capsule().fill(.black)
                                        .frame(width: g.size.width * (i < index ? 1 : i == index ? progress : 0))
                                }
                            }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)
            }
            FriendBoardView(friend: who[index],
                            nextLabel: request.auto ? (index == who.count - 1 ? "Finish" : "Next") : nil,
                            onNext: request.auto ? { next() } : nil,
                            onClose: close,
                            busy: $busy, topDim: $topDim)
                .id(who[index].id)
        }
        .overlay(alignment: .top) {
            // the progress bars sit above the board, outside the scrim, so darken them to match
            Color.clear.frame(height: 14)
                .overlay(alignment: .bottom) { Color.black.opacity(topDim).frame(height: 160) }
                .allowsHitTesting(false)
        }
    }

    private var caughtUp: some View {
        VStack(spacing: 0) {
            Circle().fill(.black).frame(width: 68, height: 68)
                .overlay(Image(systemName: "checkmark").font(.system(size: 28, weight: .semibold)).foregroundStyle(.white))
                .padding(.bottom, 18)
            Text("All caught up").font(.system(size: 24, weight: .semibold)).padding(.bottom, 8)
            Text("You’ve seen everything new.\nSee you next week.")
                .multilineTextAlignment(.center)
                .font(.callout).foregroundStyle(inkSoft)
            Button("Done") { close() }
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 26).padding(.vertical, 12)
                .background(.black, in: Capsule())
                .buttonStyle(PressableStyle())
                .padding(.top, 26)
        }
    }

    private func next() {
        store.markSeen(who[index].id)
        progress = 0
        busy = false
        if index + 1 >= who.count { finished = true } else { index += 1 }
    }
}
