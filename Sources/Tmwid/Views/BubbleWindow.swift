import SwiftUI
import AppKit

@MainActor
public final class BubbleWindowController {
    private var window: NSWindow?
    private let state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public func showIfNeeded() {
        if state.isEmpty {
            hide()
            return
        }
        if window == nil { makeWindow() }
        window?.orderFrontRegardless()
    }

    public func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() {
        let content = BubbleContent(state: state)
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: 240, height: 90)

        let w = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.contentView = host
        if let screen = NSScreen.main {
            let margin: CGFloat = 20
            let x = screen.visibleFrame.maxX - host.frame.width - margin
            let y = screen.visibleFrame.minY + margin
            w.setFrameOrigin(NSPoint(x: x, y: y))
        }
        window = w
    }
}
