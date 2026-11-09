import SwiftUI

/// "From my posts": answer the prompt with something already pinned this month. The post stays on its own
/// day and gets the prompt tag.
struct PastPostPicker: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onPick: (Post.ID) -> Void

    @State private var selected: Post.ID?

    private struct Entry: Identifiable { let post: Post; let day: Int; var id: Post.ID { post.id } }

    /// Newest day first; within a day, in posting order.
    private var entries: [Entry] {
        store.days.reversed().flatMap { day in day.posts.map { Entry(post: $0, day: day.id) } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    Text("Answer with a post you made")
                        .font(.system(size: 19, weight: .semibold))
                    Text(store.prompt)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.5))
                }
                .padding(.top, 8).padding(.bottom, 22)

                if entries.isEmpty {
                    Text("Nothing pinned yet this month.")
                        .font(.system(size: 14)).foregroundStyle(.black.opacity(0.5)).padding(.top, 40)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 26) {
                        ForEach(entries) { entry in
                            VStack(spacing: 8) {
                                PostView(post: entry.post, animated: false)
                                    .scaleEffect(selected == entry.id ? 1.05 : 1)
                                    .overlay(alignment: .topTrailing) {
                                        if selected == entry.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 26, height: 26)
                                                .background(.black, in: Circle())
                                                .offset(x: 2, y: -4)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                Text(store.shortLabel(entry.day))
                                    .font(.system(size: 12.5)).foregroundStyle(.black.opacity(0.45))
                            }
                            .contentShape(.rect)
                            .onTapGesture { withAnimation(.snappy(duration: 0.25)) { selected = entry.id } }
                            .accessibilityAddTraits(selected == entry.id ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 90, for: .scrollContent)
            .background(Color("Paper"))
            .overlay(alignment: .bottom) {
                Button {
                    if let selected { dismiss(); onPick(selected) }
                } label: {
                    Text("Use this post")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 26).padding(.vertical, 14)
                        .background(.black, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(selected == nil)
                .opacity(selected == nil ? 0.25 : 1)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Color("Paper").opacity(0), Color("Paper")], startPoint: .top, endPoint: .center))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(.black) }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationBackground(Color("Paper"))
        .tint(.black)
    }
}
