import Foundation
import Combine

@MainActor
final class FrameAnimator: ObservableObject {
    let prefix: String
    let count: Int
    let fps: Double

    @Published private(set) var index: Int = 0

    private var timer: AnyCancellable?

    init(prefix: String, count: Int, fps: Double) {
        self.prefix = prefix
        self.count = max(1, count)
        self.fps = fps
    }

    var currentFrameName: String { frameName(at: index) }

    func frameName(at i: Int) -> String {
        String(format: "%@-%03d", prefix, i + 1)
    }

    func advance() {
        index = (index + 1) % count
    }

    func start() {
        let interval = 1.0 / fps
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.advance() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
