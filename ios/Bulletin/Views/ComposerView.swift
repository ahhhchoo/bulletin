import SwiftUI

/// "Whats on your mind..." as a chat bubble you start from, at the foot of the board. Tapping it opens the composer.
///
/// It is quiet, but it invites a tap: when the board scrolls it into view it pops in, a text caret blinks in it like
/// a field waiting for you, and every few seconds it gives a small nudge until you scroll away or tap it.
struct ComposerBubble: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let action: () -> Void

    @State private var inView = false
    @State private var popped = false
    @State private var caretOn = true
    @State private var nudges = 0
    @State private var caretGone = false
    @MainActor private static var greeted = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 1) {
                // the caret of an empty field
                Rectangle()
                    .fill(.black.opacity(0.55))
                    .frame(width: 1.5, height: 15)
                    .opacity(caretGone ? 0 : (reduceMotion ? 0.6 : (caretOn ? 1 : 0.1)))
                Text(store.answeringPrompt ? "answer the prompt…" : "Whats on your mind...")
                    .font(Typo.pixel(12))
                    .foregroundStyle(.black.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.leading, 18)
            .padding(.trailing, 22)
            .frame(width: 186.6, height: 51.4, alignment: .leading)
            .background(SpeechBubble().fill(.black.opacity(0.05)))
            .overlay(SpeechBubble().stroke(.black.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: store.isComposing) { _, composing in composing }
        // pop in when it scrolls into view, settle back out when it leaves
        .scaleEffect(popped || reduceMotion ? 1 : 0.9, anchor: .bottomTrailing)
        .rotationEffect(.degrees(popped || reduceMotion ? 0 : 3), anchor: .bottomTrailing)
        .opacity(popped || reduceMotion ? 1 : 0.4)
        // the nudge: a small lift and wiggle from the tail
        .keyframeAnimator(initialValue: Nudge(), trigger: nudges) { content, v in
            content
                .scaleEffect(v.scale, anchor: .bottomTrailing)
                .rotationEffect(.degrees(v.tilt), anchor: .bottomTrailing)
                .offset(y: v.lift)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.06, duration: 0.18)
                SpringKeyframe(1.0, duration: 0.5, spring: .bouncy)
            }
            KeyframeTrack(\.tilt) {
                CubicKeyframe(-2.5, duration: 0.14)
                CubicKeyframe(1.5, duration: 0.16)
                SpringKeyframe(0, duration: 0.45, spring: .bouncy)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(-4, duration: 0.18)
                SpringKeyframe(0, duration: 0.5, spring: .bouncy)
            }
        }
        .onScrollVisibilityChange(threshold: 0.7) { visible in
            inView = visible
            if visible { caretGone = false }
            withAnimation(.spring(duration: 0.55, bounce: 0.4)) { popped = visible }
        }
        .task(id: inView) {
            guard !reduceMotion else { return }
            guard inView else { caretOn = true; return }
            // the caret blinks a few times each time the bubble lands, then goes away instead of sitting frozen
            caretOn = true
            try? await Task.sleep(for: .milliseconds(500))
            // the nudge is only the first time per launch
            if !Self.greeted { Self.greeted = true; nudges += 1 }
            for _ in 0..<3 {
                withAnimation(.easeInOut(duration: 0.2)) { caretOn = false }
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeInOut(duration: 0.2)) { caretOn = true }
                try? await Task.sleep(for: .milliseconds(550))
            }
            withAnimation(.easeOut(duration: 0.4)) { caretGone = true }
        }
    }

    private struct Nudge {
        var scale = 1.0
        var tilt = 0.0
        var lift = 0.0
    }
}

/// The bubble outline from BRD-01 (186.6 x 51.4), with a small tail at the bottom-right.
struct SpeechBubble: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 186.613, sy = r.height / 51.4444
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        var p = Path()
        p.move(to: pt(160, 0))
        p.addCurve(to: pt(184, 24), control1: pt(173.255, 0), control2: pt(184, 10.7452))
        p.addCurve(to: pt(175.69, 42.1602), control1: pt(184, 31.256), control2: pt(180.779, 37.7593))
        p.addCurve(to: pt(186.07, 49.5342), control1: pt(178.878, 44.9737), control2: pt(183.007, 47.7915))
        p.addCurve(to: pt(185.745, 51.3682), control1: pt(186.929, 50.0224), control2: pt(186.731, 51.3101))
        p.addCurve(to: pt(175.5, 51), control1: pt(183.496, 51.4998), control2: pt(180.08, 51.5089))
        p.addCurve(to: pt(160, 48), control1: pt(166.5, 50), control2: pt(160, 48))
        p.addLine(to: pt(24, 48))
        p.addCurve(to: pt(0, 24), control1: pt(10.7452, 48), control2: pt(0, 37.2548))
        p.addCurve(to: pt(24, 0), control1: pt(0, 10.7452), control2: pt(10.7452, 0))
        p.closeSubpath()
        return p
    }
}
