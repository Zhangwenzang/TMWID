import SwiftUI

public struct StatusItemView: View {
    let kind: StatusKind
    let count: Int
    let size: CGFloat
    var onTap: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    @StateObject private var animator: FrameAnimator

    public init(kind: StatusKind, count: Int, size: CGFloat = 48, onTap: (() -> Void)? = nil, onHover: ((Bool) -> Void)? = nil) {
        self.kind = kind
        self.count = count
        self.size = size
        self.onTap = onTap
        self.onHover = onHover
        let cfg = Self.config(for: kind)
        _animator = StateObject(wrappedValue: FrameAnimator(
            prefix: cfg.prefix, count: cfg.count, fps: cfg.fps))
    }

    public var body: some View {
        Image(nsImage: animator.currentImage)
            .resizable()
            .interpolation(.none)
            .frame(width: size, height: size)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onAppear { animator.start() }
            .onDisappear { animator.stop() }
            .onTapGesture { onTap?() }
            .onHover { hovering in onHover?(hovering) }
    }

    private static func config(for kind: StatusKind) -> (prefix: String, count: Int, fps: Double) {
        switch kind {
        case .working: return ("working", 14, 10)
        case .done:    return ("done", 10, 6)
        case .ask:     return ("ask", 12, 8)
        case .apiErr:  return ("apierr", 50, 12)
        }
    }
}
