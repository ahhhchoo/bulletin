import SwiftUI

private let ink = Color.black
private let inkSoft = Color.black.opacity(0.5)
private let unseenBlue = Color(red: 0, green: 0.471, blue: 0.988)   // #0078FC

/// The page behind the person button on the Friends tab: people asking to be on your list, what happened since you
/// last looked (notes on your photos, replies to yours), and your guest list.
struct GuestsPage: View {
    @Environment(FriendsStore.self) private var friends
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    /// People matching what is typed who are not on the list yet.
    private var matches: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let onList = Set(friends.guests.map { $0.name.lowercased() })
        return Friend.names.filter { $0.lowercased().contains(q) && !onList.contains($0.lowercased()) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color("Paper").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if let who = friends.addBack { requests(who) }
                    activity
                    guestList
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            header
        }
        .animation(.snappy, value: friends.addBack)
        .animation(.snappy, value: friends.guests)
        // looking at the page is what reads the activity
        .onDisappear { friends.markActivityRead() }
    }

    private var header: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(stops: [.init(color: Color("Paper"), location: 0.78), .init(color: Color("Paper").opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 112)
                .allowsHitTesting(false)
            Text("Guests").font(.system(size: 26, weight: .bold))
                .padding(.leading, 20).padding(.top, 57)
                .allowsHitTesting(false)
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17)).foregroundStyle(.black)
                    .frame(width: 44, height: 44).contentShape(.rect)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 12).padding(.top, 53)
            .accessibilityLabel("Close")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: requests

    private func requests(_ who: Friend) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Requests")
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Face(color: who.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(who.name) put you on her list").font(.system(size: 15, weight: .semibold))
                        if friends.isFull {
                            Text("Your list is full. Take someone off first.")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(Color("DayPink"))
                        } else {
                            Text("Add her to yours?").font(.system(size: 13, weight: .medium)).foregroundStyle(inkSoft)
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button("Not now") { friends.skipAddBack() }
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(inkSoft)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                    Button("Add") { friends.addBackTapped() }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 7)
                        .background(.black, in: Capsule())
                        .opacity(friends.isFull ? 0.25 : 1)
                        .disabled(friends.isFull)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }

    // MARK: activity

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Activity")
            if friends.activity.isEmpty {
                Text("Nothing new yet.")
                    .font(.system(size: 14).italic()).foregroundStyle(inkSoft)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(friends.activity.enumerated()), id: \.element.id) { i, item in
                        activityRow(item)
                            .overlay(alignment: .top) { if i > 0 { Rectangle().fill(.black.opacity(0.08)).frame(height: 1) } }
                    }
                }
            }
        }
    }

    private func activityRow(_ item: Activity) -> some View {
        HStack(spacing: 12) {
            Face(color: item.color)
            VStack(alignment: .leading, spacing: 2) {
                (Text(item.who).fontWeight(.semibold) + Text(" \(item.text)"))
                    .font(.system(size: 15))
                    .foregroundStyle(item.unread ? ink : ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.when.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.black.opacity(0.3))
            }
            Spacer(minLength: 8)
            if item.unread {
                Circle().fill(unseenBlue).frame(width: 9, height: 9)
            }
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.who) \(item.text)\(item.unread ? ", new" : "")")
    }

    // MARK: guest list

    private var guestList: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Guest list (\(friends.guestCount)/\(FriendsStore.guestCap))")
            Text(friends.isFull ? "Full. Take someone off to add another"
                 : "People who can see your bulletin · \(friends.spotsLeft) spot\(friends.spotsLeft == 1 ? "" : "s") left")
                .font(.system(size: 14))
                .foregroundStyle(friends.isFull ? Color("DayPink") : .black.opacity(0.4))
                .padding(.top, 4)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .medium)).foregroundStyle(.black.opacity(0.35))
                TextField("Add by username", text: $query)
                    .font(.system(size: 15))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.done)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 16)

            ShareLink(item: "Come see my bulletin on Bulletin") {
                Label("Invite someone", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.black.opacity(0.7))
                    .padding(.top, 14)
            }

            VStack(spacing: 0) {
                let typed = query.trimmingCharacters(in: .whitespaces)
                if !typed.isEmpty {
                    ForEach(matches, id: \.self) { name in
                        row(name: name, color: Friend.color(at: friends.guestCount), trailing: addButton(name))
                    }
                    if matches.isEmpty {
                        row(name: typed, color: Color(white: 0.851), trailing: addButton(typed, label: "Invite"))
                    }
                }
                ForEach(friends.guests) { guest in
                    row(name: guest.name, color: guest.color, trailing:
                        Button { withAnimation(.snappy) { friends.removeGuest(guest.id) } } label: {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.5))
                                .frame(width: 28, height: 28)
                                .background(.black.opacity(0.07), in: Circle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Remove \(guest.name)"))
                }
            }
            .padding(.top, 8)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(Typo.pixel(18)).foregroundStyle(.black)
    }

    private func row<T: View>(name: String, color: Color, trailing: T) -> some View {
        HStack(spacing: 12) {
            Face(color: color)
            Text(name).font(.system(size: 16, weight: .medium))
            Spacer()
            trailing
        }
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.08)).frame(height: 1) }
    }

    private func addButton(_ name: String, label: String = "Add") -> some View {
        Button {
            friends.addGuest(name: name)
            query = ""
        } label: {
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(.black, in: Capsule())
                .opacity(friends.isFull ? 0.25 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(friends.isFull)
    }
}
