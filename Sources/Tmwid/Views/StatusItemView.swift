import SwiftUI

public struct StatusItemView: View {
    let kind: StatusKind
    let count: Int
    let size: CGFloat
    var onTap: (() -> Void)?
    @StateObject private var animator: FrameAnimator

    public init(kind: StatusKind, count: Int, size: CGFloat = 48, onTap: (() -> Void)? = nil) {
        self.kind = kind
        self.count = count
        self.size = size
        self.onTap = onTap
        let cfg = Self.config(for: kind)
        _animator = StateObject(wrappedValue: FrameAnimator(
            prefix: cfg.prefix, count: cfg.count, fps: cfg.fps))
    }

    public var body: some View {
        VStack(spacing: size > 24 ? 4 : 2) {
            Image(nsImage: animator.currentImage)
                .resizable()
                .interpolation(.none)
                .frame(width: size, height: size)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: size > 24 ? 6 : 3))
            if size > 24 {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                    .monospacedDigit()
            }
        }
        .contentShape(Rectangle())
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
        .onTapGesture { onTap?() }
    }

    private static func config(for kind: StatusKind) -> (prefix: String, count: Int, fps: Double) {
        switch kind {
        case .working: return ("working", 14, 10)
        case .done:    return ("done", 10, 6)
        case .ask:     return ("ask", 12, 8)
        }
    }
}
