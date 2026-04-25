import SwiftUI

struct StatusItemView: View {
    let kind: StatusKind
    let count: Int
    @StateObject private var animator: FrameAnimator

    init(kind: StatusKind, count: Int) {
        self.kind = kind
        self.count = count
        let cfg = Self.config(for: kind)
        _animator = StateObject(wrappedValue: FrameAnimator(
            prefix: cfg.prefix, count: cfg.count, fps: cfg.fps))
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(animator.currentFrameName, bundle: .module)
                .resizable()
                .interpolation(.none)
                .frame(width: 48, height: 48)
                .background(Color.white)
                .cornerRadius(6)
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                .monospacedDigit()
        }
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
    }

    private static func config(for kind: StatusKind) -> (prefix: String, count: Int, fps: Double) {
        switch kind {
        case .working: return ("working", 14, 10)
        case .done:    return ("done", 10, 6)
        case .ask:     return ("ask", 12, 8)
        }
    }
}
