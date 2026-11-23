import SwiftUI

/// What the board shows on a month with nothing pinned yet: a blank sticky waiting to be filled, a line about what
/// the board is for, and a quick way into this month's prompt. (BRD-08, and the first-post screen.)
struct NewMonthEmptyState: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        VStack(spacing: 0) {
            sticky
                .frame(height: Paper.minHeight + 26)
                .padding(.top, 6)
            Text("A fresh \(store.monthName).")
                .font(.system(size: 24, weight: .heavy)).tracking(-0.7)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            Text("Pin a thought, a photo or a note. It lands on today.")
                .font(.system(size: 14))
                .foregroundStyle(.black.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.top, 6).padding(.horizontal, 24)
            Button { store.answeringPrompt = true } label: {
                Text("Answer this month’s prompt")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20).frame(height: 42)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().strokeBorder(.black.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .onAppear {
            if reduceMotion { landed = true } else { withAnimation(.spring(duration: 0.6, bounce: 0.35).delay(0.1)) { landed = true } }
        }
        .accessibilityElement(children: .contain)
    }

    /// A blank sticky and a blank photo behind it, both empty and dashed like the Shelf's covers, with a pin in the sticky.
    private var sticky: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.black.opacity(0.15), style: StrokeStyle(lineWidth: 1.3, dash: [5, 4])))
                .frame(width: 110, height: 130)
                .rotationEffect(.degrees(landed ? 9 : 2))
                .offset(x: landed ? 58 : 20, y: landed ? 6 : 0)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Paper.stickyFill.opacity(0.7))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.black.opacity(0.18), style: StrokeStyle(lineWidth: 1.3, dash: [5, 4])))
                Pushpin().offset(y: 10)
            }
            .frame(width: Paper.width, height: Paper.minHeight)
            .rotationEffect(.degrees(landed ? -4 : 0))
            .offset(x: landed ? -34 : 0, y: landed ? 0 : -6)
        }
    }
}
