import SwiftUI


/// "There are notes under this photo": the same little count as a stack's, "+4" on a black capsule.
struct NoteBadge: View {
    let count: Int

    var body: some View {
        CountBadge(count: count)
            .accessibilityLabel("\(count) note\(count == 1 ? "" : "s") under this photo")
    }
}

/// Where you write a note or a reply: the note itself, on the same paper and tape it will have on the photo, over the
/// same dark backdrop, with your name and a dot in your color already on it.
struct NoteWriter: View {
    let title: String
    let isReply: Bool
    var sendLabel: String?
    var initial = ""
    let onCancel: () -> Void
    let onSend: (String) -> Void
    @State private var text: String
    @State private var landed = false
    @FocusState private var focused: Bool
    private let limit = 140

    init(title: String, isReply: Bool, sendLabel: String? = nil, initial: String = "",
         onCancel: @escaping () -> Void, onSend: @escaping (String) -> Void) {
        self.title = title; self.isReply = isReply; self.sendLabel = sendLabel; self.initial = initial
        self.onCancel = onCancel; self.onSend = onSend
        _text = State(initialValue: initial)
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear      // the photo stays up above, small, with the screen's own dark backdrop behind
                .contentShape(.rect)
                .ignoresSafeArea()
                .onTapGesture { focused = false }

            VStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 0) {
                    TextField(isReply ? "Write a reply…" : "Write something…", text: $text, axis: .vertical)
                        .focused($focused)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black)
                        .tint(.black)
                        .lineLimit(3...7)
                        .padding(.trailing, 36)
                        .onChange(of: text) { _, new in if new.count > limit { text = String(new.prefix(limit)) } }
                    Text("- You")
                        .font(.system(size: 11)).foregroundStyle(.black)
                        .padding(.top, 26)
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(Color(red: 0.75, green: 0.91, blue: 0.85)).frame(width: 24, height: 24)
                        .padding(.trailing, 16).padding(.bottom, 12)
                }
                .notePaper()
                .frame(width: 328)
                .accessibilityLabel(title)
                // it drops in and the tape lands on it
                .rotationEffect(.degrees(landed ? -1.2 : 3))
                .offset(y: landed ? 0 : 36)
                .opacity(landed ? 1 : 0)

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(.white.opacity(0.14), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    }
                    Button { onSend(trimmed) } label: {
                        Text(sendLabel ?? (isReply ? "Reply" : "Stick it"))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(.white, in: Capsule())
                            .opacity(trimmed.isEmpty ? 0.3 : 1)
                    }
                    .disabled(trimmed.isEmpty)
                }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(PressableStyle())
                .overlay(alignment: .trailing) {
                    Text("\(text.count)/\(limit)")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                        .offset(x: 70)
                        .opacity(text.isEmpty ? 0 : 1)
                }
            }
            .padding(.top, 252)
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: landed)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { landed = true }
            focused = true
        }
    }
}
