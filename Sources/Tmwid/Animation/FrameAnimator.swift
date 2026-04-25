import Foundation
import Combine
import AppKit

@MainActor
public final class FrameAnimator: ObservableObject {
    public let prefix: String
    public let count: Int
    public let fps: Double

    @Published public private(set) var index: Int = 0

    private var timer: AnyCancellable?
    private var cachedImages: [NSImage] = []

    public init(prefix: String, count: Int, fps: Double) {
        self.prefix = prefix
        self.count = max(1, count)
        self.fps = fps
        self.cachedImages = (0..<self.count).map { i in
            let name = String(format: "%@-%03d", prefix, i + 1)
            if let bundle = Bundle.tmwidResources,
               let url = bundle.urlForImageResource(name),
               let img = NSImage(contentsOf: url) {
                return img
            }
            // Fallback: try loading from named
            return NSImage(named: name) ?? NSImage()
        }
    }

    public var currentFrameName: String { frameName(at: index) }

    public var currentImage: NSImage {
        guard index < cachedImages.count else { return NSImage() }
        return cachedImages[index]
    }

    public func frameName(at i: Int) -> String {
        String(format: "%@-%03d", prefix, i + 1)
    }

    public func advance() {
        index = (index + 1) % count
    }

    public func start() {
        let interval = 1.0 / fps
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.advance() }
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }
}

extension Bundle {
    /// The resource bundle for the Tmwid library target.
    static let tmwidResources: Bundle? = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }()
}
