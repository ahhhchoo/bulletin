import SwiftUI

private let cardGray = Color.white
private let avatarGray = Color(white: 0.87)
private let inkSoft = Color.black.opacity(0.5)

struct FriendsView: View {
    @Environment(FriendsStore.self) private var friends
    @State private var queue: QueueRequest?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if friends.addBack != nil { AddBackCard() }
                FriendsCard(openQueue: open)
                GuestListCard()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color("Paper"))
        .animation(.snappy, value: friends.addBack)
        .fullScreenCover(item: $queue) { request in
            FriendQueueView(request: request) { queue = nil }
        }
    }

    /// Tap the chip: the boards with news, in order. Tap a friend with news: the queue starting on them.
    /// Tap a friend with nothing new: just their board.
    private func open(startingAt first: Friend?) {
        var list = friends.withNews
        if let first, !first.hasNew { queue = QueueRequest(who: [first], auto: false); return }
        guard !list.isEmpty else { return }
        if let first, let i = list.firstIndex(of: first) { list.move(fromOffsets: [i], toOffset: 0) }
        queue = QueueRequest(who: list, auto: true)
    }
}

// MARK: - Friends card

private struct FriendsCard: View {
    @Environment(FriendsStore.self) private var friends
    let openQueue: (Friend?) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Friends").font(.system(size: 24, weight: .medium))
                    Text("People who put you on their guest list")
                        .font(.footnote.weight(.medium)).foregroundStyle(inkSoft)
                }
                Spacer(minLength: 8)
                Doorbell(count: friends.withNews.count) { openQueue(nil) }
            }
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(friends.ordered) { friend in
                    FriendAvatar(friend: friend) { openQueue(friend) }
                }
            }
            .padding(.top, 20)
            .animation(.snappy, value: friends.ordered)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardGray, in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct Doorbell: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        if count > 0 {
            Button(action: action) {
                HStack(spacing: 7) {
                    Circle().fill(Color("DayPink")).frame(width: 8, height: 8)
                    Text("\(count) new")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(.black, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("\(count) boards have new things")
        } else {
            HStack(spacing: 7) {
                Circle().fill(Color.black.opacity(0.25)).frame(width: 8, height: 8)
                Text("all quiet")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.45))
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(Color.black.opacity(0.07), in: Capsule())
        }
    }
}

private struct FriendAvatar: View {
    let friend: Friend
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Circle().fill(friend.color)
                        .frame(width: 60, height: 60)
                        .overlay(Text(friend.name.prefix(1)).font(.system(size: 20, weight: .semibold)).foregroundStyle(.black.opacity(0.45)))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .padding(2.5)
                        .overlay { if friend.hasNew { Circle().strokeBorder(Color("DayPink"), lineWidth: 2.5) } }
                    if friend.hasNew {
                        Circle().fill(Color("DayPink")).frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(cardGray, lineWidth: 2.5))
                            .offset(x: 1, y: -1)
                    }
                }
                Text(friend.name).font(.footnote.weight(.medium)).foregroundStyle(inkSoft)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(friend.hasNew ? "\(friend.name), has something new" : friend.name)
    }
}

// MARK: - Add back

private struct AddBackCard: View {
    @Environment(FriendsStore.self) private var friends

    var body: some View {
        if let who = friends.addBack {
            HStack(spacing: 14) {
                Circle().fill(who.color).frame(width: 48, height: 48)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(who.name) put you on her list").font(.system(size: 16, weight: .semibold))
                    if friends.isFull {
                        Text("Your list is full. Take someone off first.")
                            .font(.footnote.weight(.medium)).foregroundStyle(Color("DayPink"))
                    } else {
                        Text("Add her to yours?").font(.footnote.weight(.medium)).foregroundStyle(inkSoft)
                    }
                }
                Spacer(minLength: 8)
                VStack(spacing: 6) {
                    Button("Add") { friends.addBackTapped() }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.black, in: Capsule())
                        .opacity(friends.isFull ? 0.25 : 1)
                        .disabled(friends.isFull)
                    Button("Not now") { friends.skipAddBack() }
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(inkSoft)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }
}

// MARK: - Guest list

private struct GuestListCard: View {
    @Environment(FriendsStore.self) private var friends

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Guest list (\(friends.guestCount)/\(FriendsStore.guestCap))")
                        .font(.system(size: 24, weight: .medium))
                    Text("People who can see your bulletin")
                        .font(.footnote.weight(.medium)).foregroundStyle(inkSoft)
                }
                Spacer(minLength: 8)
                Button("Edit") {}
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.12)))
                    .buttonStyle(PressableStyle())
            }
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(0..<FriendsStore.guestCap, id: \.self) { i in
                    Slot(filled: i < friends.guestCount, full: friends.isFull, color: Friend.color(at: i + 3))
                }
            }
            .padding(.top, 16)
            .animation(.snappy, value: friends.guestCount)
            Text(friends.isFull ? "Full. Take someone off first"
                 : "\(friends.spotsLeft) spot\(friends.spotsLeft == 1 ? "" : "s") left")
                .font(.footnote.weight(.medium))
                .foregroundStyle(friends.isFull ? Color("DayPink") : inkSoft)
                .padding(.top, 12)
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardGray, in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 3)
    }
}

/// One place on the guest list: a person (gray circle, where their picture goes) or an open spot (dashed).
private struct Slot: View {
    let filled: Bool
    let full: Bool
    let color: Color

    var body: some View {
        Group {
            if filled {
                Circle().fill(full ? Color("DayPink") : color)
                    .overlay(Circle().strokeBorder(cardGray, lineWidth: 2))
            } else {
                Circle().strokeBorder(.black.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .aspectRatio(1, contentMode: .fit)
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
                            busy: $busy)
                .id(who[index].id)
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
