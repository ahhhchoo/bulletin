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
            .overlay { if friends.ordered.isEmpty { SharedEmptyState() } }
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


// MARK: - Empty state (FRN-02)

/// What the Shared tab shows before anyone has added you: a small pile of what will arrive here, and a way to invite
/// the first person.
private struct SharedEmptyState: View {
    @Environment(TipsStore.self) private var tips
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sharing = false
    @State private var sent = false
    @State private var landed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 96)
            pile
                .frame(height: 300)
            Text("It’s quiet in here.")
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.9)
                .padding(.top, 14)
            Text("When friends add you, their latest photos, notes and entries land here.")
                .font(.system(size: 15))
                .foregroundStyle(.black.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 12)
            if sent {
                sentRow
                    .padding(.top, 20)
                    .transition(.scale(scale: 0.94).combined(with: .opacity).combined(with: .offset(y: 8)))
            }
            Spacer(minLength: 16)
            Button { sharing = true } label: {
                Text(sent ? "Invite someone else" : "Invite someone")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.black, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            Text("One link, one person, good for a week")
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.45))
                .padding(.top, 12)
        }
        .padding(.horizontal, 27)
        .padding(.bottom, 130)
        .animation(.spring(duration: 0.5, bounce: 0.3), value: sent)
        .sheet(isPresented: $sharing) {
            ActivityView(items: ["Join me on Bulletin", tips.inviteURL]) { didSend in
                sharing = false
                if didSend { sent = true; tips.finishInvite() }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear { withAnimation(.spring(duration: 0.8, bounce: 0.3)) { landed = true } }
    }

    /// A photo, a sticky and a folded note, loosely stacked like a real bulletin.
    private var pile: some View {
        ZStack {
            // the photo already has its own red pin, so no other dot
            PostView(post: Post(kind: .photo(caption: "sandwiches at alamo square"), rotation: 0, image: SamplePhotos.onboarding), animated: false, tilt: 0)
                .rotationEffect(.degrees(-8))
                .offset(x: -62, y: -4)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
            PostView(post: Post(kind: .sticky(text: "tried the new place on 5th"), rotation: 0), animated: false, tilt: 0)
                .rotationEffect(.degrees(5))
                .offset(x: 70, y: -40)
                .shadow(color: .black.opacity(0.16), radius: 12, y: 8)
            PostView(post: Post(kind: .journal(title: "a slow, good day", body: "Walked the long way to work today."), rotation: 0),
                     animated: false, tilt: 0, backSheet: .intro)
                .rotationEffect(.degrees(-2))
                .offset(x: 8, y: 62)
                .shadow(color: .black.opacity(0.16), radius: 12, y: 8)
        }
        .scaleEffect(0.84)
        .scaleEffect(landed || reduceMotion ? 1 : 0.9)
        .opacity(landed || reduceMotion ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var sentRow: some View {
        HStack(spacing: 12) {
            Text("1")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 38, height: 38)
                .background(Color("Sticky"), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("Invite sent").font(.system(size: 15, weight: .semibold))
                Text("Waiting on them · 7 days left").font(.system(size: 13)).foregroundStyle(.black.opacity(0.5))
            }
            Spacer()
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.black.opacity(0.12), lineWidth: 1))
    }
}
