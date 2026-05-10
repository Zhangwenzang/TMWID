import SwiftUI
import AppKit
import Combine

public struct MenuBarLabel: View {
    @ObservedObject var state: AppState
    @StateObject private var workingAnim = FrameAnimator(prefix: "working", count: 14, fps: 10)
    @StateObject private var askAnim = FrameAnimator(prefix: "ask", count: 12, fps: 8)
    @StateObject private var doneAnim = FrameAnimator(prefix: "done", count: 10, fps: 6)
    @StateObject private var apiErrAnim = FrameAnimator(prefix: "apierr", count: 50, fps: 12)

    @State private var wc = 0
    @State private var ac = 0
    @State private var dc = 0
    @State private var ec = 0

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        Image(nsImage: compositeImage())
            .onAppear { syncCounts(); startAll() }
            .onDisappear { stopAll() }
            .onReceive(state.objectWillChange) { _ in
                DispatchQueue.main.async { syncCounts() }
            }
    }

    private func syncCounts() {
        wc = state.workingCount
        ac = state.askCount
        dc = state.doneCount
        ec = state.apiErrCount
    }

    private func compositeImage() -> NSImage {
        let iconSize: CGFloat = 16
        let iconRadius: CGFloat = 3
        let gap: CGFloat = 2       // icon-to-text gap
        let groupGap: CGFloat = 6  // gap between groups
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        let height: CGFloat = 18

        struct ItemInfo {
            let image: NSImage
            let count: Int
        }

        var items: [ItemInfo] = [
            ItemInfo(image: workingAnim.currentImage, count: wc),
            ItemInfo(image: askAnim.currentImage, count: ac),
            ItemInfo(image: doneAnim.currentImage, count: dc),
        ]
        if ec > 0 {
            items.append(ItemInfo(image: apiErrAnim.currentImage, count: ec))
        }

        // Measure total width
        var totalWidth: CGFloat = 0
        var itemWidths: [(iconW: CGFloat, textW: CGFloat, text: NSAttributedString)] = []
        for item in items {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: item.count > 0 ? NSColor.white : NSColor.white.withAlphaComponent(0.5),
            ]
            let str = NSAttributedString(string: "\(item.count)", attributes: attrs)
            let textSize = str.size()
            itemWidths.append((iconW: iconSize, textW: ceil(textSize.width), text: str))
            totalWidth += iconSize + gap + ceil(textSize.width)
        }
        totalWidth += groupGap * CGFloat(items.count - 1)

        // Draw composite
        let composite = NSImage(size: NSSize(width: totalWidth, height: height))
        composite.lockFocus()

        var x: CGFloat = 0
        for (i, item) in items.enumerated() {
            let info = itemWidths[i]
            let alpha: CGFloat = item.count > 0 ? 1.0 : 0.5
            let iconY = (height - iconSize) / 2

            // Draw icon with rounded corners and white background
            NSGraphicsContext.saveGraphicsState()
            let iconRect = NSRect(x: x, y: iconY, width: iconSize, height: iconSize)
            let clipPath = NSBezierPath(roundedRect: iconRect, xRadius: iconRadius, yRadius: iconRadius)
            clipPath.addClip()
            NSColor.white.withAlphaComponent(alpha).setFill()
            clipPath.fill()
            item.image.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: alpha)
            NSGraphicsContext.restoreGraphicsState()

            x += iconSize + gap

            // Draw count text
            let textY = (height - info.text.size().height) / 2
            info.text.draw(at: NSPoint(x: x, y: textY))
            x += info.textW

            if i < items.count - 1 {
                x += groupGap
            }
        }

        composite.unlockFocus()
        composite.isTemplate = false
        return composite
    }

    private func startAll() {
        workingAnim.start()
        askAnim.start()
        doneAnim.start()
        apiErrAnim.start()
    }

    private func stopAll() {
        workingAnim.stop()
        askAnim.stop()
        doneAnim.stop()
        apiErrAnim.stop()
    }
}
