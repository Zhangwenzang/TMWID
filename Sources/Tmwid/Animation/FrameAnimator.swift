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
        self.cachedImages = Self.loadFrames(prefix: prefix, count: self.count)
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

    private static func loadFrames(prefix: String, count: Int) -> [NSImage] {
        let bundle = resourceBundle()
        return (0..<count).map { i in
            let name = String(format: "%@-%03d", prefix, i + 1)

            // Universal build: asset catalog compiled to Assets.car — use NSImage(named:) via bundle
            if let bundle = bundle, let img = bundle.image(forResource: name) {
                return img
            }

            // Single-arch SPM build: flat xcassets dir next to executable
            if let bundlePath = bundle?.resourcePath {
                let pngPath = "\(bundlePath)/Assets.xcassets/\(name).imageset/\(name).png"
                if let img = NSImage(contentsOfFile: pngPath) {
                    return img
                }
            }

            // Fallback: legacy bundle image resource lookup
            if let bundle = bundle,
               let url = bundle.urlForImageResource(name),
               let img = NSImage(contentsOf: url) {
                return img
            }
            return NSImage()
        }
    }

    private static func resourceBundle() -> Bundle? {
        // SPM generates Tmwid_Tmwid.bundle next to the executable
        let execURL = Bundle.main.executableURL ?? Bundle.main.bundleURL
        let bundleName = "Tmwid_Tmwid.bundle"

        // Check next to executable (packaged .app)
        let adjacentURL = execURL.deletingLastPathComponent().appendingPathComponent(bundleName)
        if FileManager.default.fileExists(atPath: adjacentURL.path) {
            return Bundle(url: adjacentURL)
        }

        // Check Contents/Resources/ (standard .app layout)
        let resourcesURL = execURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent(bundleName)
        if FileManager.default.fileExists(atPath: resourcesURL.path) {
            return Bundle(url: resourcesURL)
        }

        // Fallback to Bundle.module (works in tests and dev builds)
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }
}
