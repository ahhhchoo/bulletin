import SwiftUI

/// BRD-01 "currently into", being edited. The masthead stays where it is, the card turns into a text field
/// (caret and all), and what you were into in earlier months sits under "Looking back".
/// Return, or a tap anywhere outside the field, saves it.
struct IntoEditor: View {
    @Environment(BoardStore.self) private var store
    let close: () -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("Paper")
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture(perform: commit)

            Text("My \(store.monthName)")
                .font(Typo.scaled(24, .medium, relativeTo: .title))
                .padding(.leading, 28)
                .offset(y: 15)
                .allowsHitTesting(false)

            // Cancel throws the edit away; Done keeps it
            HStack(spacing: 8) {
                Button("Cancel", action: close)
                    .foregroundStyle(.black.opacity(0.6))
                    .modifier(PillButton())
                Button("Done", action: commit)
                    .fontWeight(.semibold)
                    .disabled(trimmed.isEmpty)
                    .modifier(PillButton())
            }
            .font(.system(size: 15))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
            .offset(y: 10)

            // the cards, exactly where they are on the board (the overlay keeps the second card from widening the layout)
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .overlay(alignment: .leading) {
                    HStack(spacing: 5) {
                        intoCard
                        Color("CardPrompt")
                            .frame(width: 348, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    }
                    .padding(.leading, 27)
                    .fixedSize()
                }
                .clipped()
                .offset(y: 59)

            PageDots(current: 0, count: 2)
                .frame(maxWidth: .infinity)
                .offset(y: 146)
                .allowsHitTesting(false)

            Text("Looking back")
                .font(Typo.scaled(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.black.opacity(0.5))
                .padding(.leading, 35)
                .offset(y: 180)
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 6) {
                    row("\(store.monthName):", trimmed.isEmpty ? store.currentlyInto : draft)
                    ForEach(store.intoEarlierThisMonth, id: \.self) { row("earlier this month:", $0) }
                    ForEach(store.intoHistory) { row("\($0.month):", $0.text) }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(TapGesture().onEnded(commit))    // empty space under the rows counts as "outside"
            .padding(.top, 206)
        }
        .foregroundStyle(.black)
        .onAppear { draft = store.currentlyInto; focused = true }
    }

    private var intoCard: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("currently into:").foregroundStyle(.black.opacity(0.5))
            TextField("what are you into?", text: $draft)
                .foregroundStyle(.black)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .tint(.black)
        }
        .font(Typo.scaled(14, .medium, relativeTo: .subheadline))
        .padding(.leading, 20)
        .frame(width: 348, height: 76, alignment: .leading)
        .background(Color("CardInto"), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    private func row(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).foregroundStyle(.black.opacity(0.5))
            Text(text).foregroundStyle(.black)
        }
        .font(Typo.scaled(14, .medium, relativeTo: .subheadline))
        .padding(.leading, 20)
        .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).strokeBorder(Color(red: 0.141, green: 0.325, blue: 0.6).opacity(0.1), lineWidth: 1))
    }

    private func commit() {
        store.setInto(draft)       // empty or unchanged keeps what was there
        close()
    }
}

private struct PillButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(.white.opacity(0.9), in: Capsule())
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .buttonStyle(PressableStyle())
    }
}
