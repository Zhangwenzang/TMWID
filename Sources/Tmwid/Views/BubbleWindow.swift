import SwiftUI
import AppKit

@MainActor
public final class BubbleWindowController {
    private var window: NSWindow?
    private var hostingView: NSHostingView<BubbleContent>?
    private let state: AppState
    private var lastFrame: NSRect = .zero

    public var onMinimize: (() -> Void)?

    public var isVisible: Bool {
        window?.isVisible ?? false
    }

    public init(state: AppState) {
        self.state = state
    }

    public func showIfNeeded() {
        if state.isEmpty {
            hide()
            return
        }
        if window == nil {
            makeWindow()
        }
        updateSize()
        window?.orderFrontRegardless()
    }

    public func hide() {
        window?.orderOut(nil)
    }

    public func minimizeToMenuBar() {
        guard let w = window, w.isVisible else { return }
        lastFrame = w.frame

        // Target: top-right corner of the screen (menu bar area)
        let target: NSRect
        if let screen = NSScreen.main {
            let x = screen.frame.maxX - 40
            let y = screen.frame.maxY - 30
            target = NSRect(x: x, y: y, width: 16, height: 16)
        } else {
            target = NSRect(x: w.frame.midX, y: w.frame.midY, width: 16, height: 16)
        }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            w.animator().setFrame(target, display: true)
            w.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                w.orderOut(nil)
                w.alphaValue = 1
                self?.onMinimize?()
            }
        })
    }

    public func restoreFromMenuBar() {
        guard let w = window else {
            makeWindow()
            updateSize()
            window?.orderFrontRegardless()
            return
        }

        // If we have no saved frame, just show normally
        guard lastFrame.width > 16 else {
            updateSize()
            w.orderFrontRegardless()
            return
        }

        // Start from menu bar area
        let start: NSRect
        if let screen = NSScreen.main {
            let x = screen.frame.maxX - 40
            let y = screen.frame.maxY - 30
            start = NSRect(x: x, y: y, width: 16, height: 16)
        } else {
            start = NSRect(x: lastFrame.midX, y: lastFrame.midY, width: 16, height: 16)
        }

        updateSize()
        let targetFrame = w.frame
        w.setFrame(start, display: false)
        w.alphaValue = 0
        w.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            w.animator().setFrame(targetFrame, display: true)
            w.animator().alphaValue = 1
        })
    }

    private func updateSize() {
        guard let host = hostingView, let w = window else { return }
        let fitting = host.fittingSize
        let newSize = NSSize(width: max(fitting.width, 80), height: max(fitting.height, 60))

        var frame = w.frame
        let dx = newSize.width - frame.width
        frame.origin.x -= dx
        frame.size = newSize
        w.setFrame(frame, display: true, animate: false)
    }

    private func makeWindow() {
        let content = BubbleContent(state: state, onMinimize: { [weak self] in
            self?.minimizeToMenuBar()
        })
        let host = NSHostingView(rootView: content)

        let fitting = host.fittingSize
        let size = NSSize(width: max(fitting.width, 80), height: max(fitting.height, 60))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .floating
        w.isMovableByWindowBackground = true
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.contentView = host

        if let screen = NSScreen.main {
            let margin: CGFloat = 20
            let x = screen.visibleFrame.maxX - size.width - margin
            let y = screen.visibleFrame.minY + margin
            w.setFrameOrigin(NSPoint(x: x, y: y))
        }

        hostingView = host
        window = w
    }
}
