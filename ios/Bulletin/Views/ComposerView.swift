import SwiftUI

/// The black "Whats on your mind..." pill on the board. Tapping it opens the composer sheet.
struct ComposerPill: View {
    @Environment(BoardStore.self) private var store
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(store.answeringPrompt ? "answer the prompt…" : "Whats on your mind...")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}
