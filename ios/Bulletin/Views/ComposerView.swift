import SwiftUI

/// "Posting works like texting: type and pin." The pill expands in place into a text field.
struct ComposerView: View {
    @Environment(BoardStore.self) private var store
    @State private var text = ""
    @State private var open = false
    @FocusState private var focused: Bool
    @Namespace private var ns

    private var placeholder: String {
        store.answeringPrompt ? "answer the prompt…" : "Whats on your mind..."
    }

    var body: some View {
        ZStack {
            if open {
                HStack(spacing: 6) {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .tint(.white)
                        .focused($focused)
                        .submitLabel(.send)
                        .onSubmit(send)
                        .padding(.leading, 16)
                        .padding(.vertical, 8)

                    Button(action: send) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 30, height: 30)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(trimmed.isEmpty)
                    .opacity(trimmed.isEmpty ? 0.35 : 1)
                    .padding(.trailing, 6)
                    .accessibilityLabel("Pin it")
                }
                .background(.black, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .matchedGeometryEffect(id: "bubble", in: ns)
                .padding(.horizontal, 24)
                .transition(.opacity)
            } else {
                Button {
                    open = true
                    focused = true
                } label: {
                    Text(placeholder)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .matchedGeometryEffect(id: "bubble", in: ns)
                .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.25), value: open)
        .onChange(of: store.answeringPrompt) { _, answering in
            if answering { open = true; focused = true }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused && trimmed.isEmpty { open = false; store.answeringPrompt = false }
        }
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func send() {
        guard !trimmed.isEmpty else { return }
        store.addSticky(text)
        text = ""
        open = false
        focused = false
    }
}
