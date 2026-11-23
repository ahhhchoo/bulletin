import SwiftUI

/// A small black speech bubble with an arrow: the tooltip. It springs in from the arrow.
struct TipBubble<Actions: View>: View {
    enum Arrow { case up(x: CGFloat), down(x: CGFloat), none }

    let title: String
    let message: String
    var arrow: Arrow = .none
    var width: CGFloat = 330
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            actions
                .padding(.top, 9)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: width, alignment: .leading)
        .background(.black, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topLeading) { if case .up(let x) = arrow { notch.offset(x: x - 8, y: -6) } }
        .overlay(alignment: .bottomLeading) { if case .down(let x) = arrow { notch.offset(x: x - 8, y: 6) } }
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
    }

    private var notch: some View {
        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
            .fill(.black)
            .frame(width: 16, height: 16)
            .rotationEffect(.degrees(45))
    }

    /// Grows out of the arrow with a little spring, and lifts a touch; with Reduce Motion it just fades.
    static func appear(from anchor: UnitPoint, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.82, anchor: anchor).combined(with: .opacity)
    }
}

extension TipBubble where Actions == EmptyView {
    init(title: String, message: String, arrow: Arrow = .none, width: CGFloat = 330) {
        self.init(title: title, message: message, arrow: arrow, width: width) { EmptyView() }
    }
}

/// The white "main" button on a tip.
struct TipButton: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(.white, in: Capsule())
    }
}

/// The quiet "Not now" next to it.
struct TipGhostButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .padding(.horizontal, 6).padding(.vertical, 9)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// "currently into" before it has been set: a bubble with a system-blue outline that says "Tap to set it" and blinks a
/// caret, so it reads as a field.
struct EmptyIntoBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let action: () -> Void
    @State private var caretOn = true

    var body: some View {
        Button(action: action) {
            HStack(spacing: 1) {
                Text("Tap to set it")
                    .font(Typo.pixel(12))
                    .foregroundStyle(.black.opacity(0.45))
                Rectangle()
                    .fill(Color(uiColor: .systemBlue))
                    .frame(width: 1.5, height: 15)
                    .opacity(reduceMotion ? 1 : (caretOn ? 1 : 0.1))
            }
            .padding(12)
            .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(uiColor: .systemBlue), lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel("Set what you are currently into")
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(530))
                caretOn.toggle()
            }
        }
    }
}

/// The iOS share sheet, with a callback for whether anything was actually sent.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onDone: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in onDone(completed) }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
