import SwiftUI
import AppKit

@MainActor
public final class BubbleWindowController {
    private var window: NSWindow?
    private var hostingView: NSHostingView<BubbleContent>?
    private let state: AppState
    private var lastFrame: NSRect = .zero
    private var isAnimating = false
    private var anchorX: CGFloat?
    private var expandTimer: Timer?
    private let maxBubbleWidth: CGFloat = 208
    private let compactBubbleHeight: CGFloat = 90
    private let singleSessionExpandedHeight: CGFloat = 212
    private let sessionRowHeight: CGFloat = 41

    public var onMinimize: (() -> Void)?
    public var onStatusTap: ((StatusKind) -> Void)?
    public var onSessionTap: ((SessionState) -> Void)?
    public var activator: SessionActivator?

    public var isVisible: Bool {
        window?.isVisible ?? false
    }

    public init(state: AppState) {
        self.state = state
    }

    public func showIfNeeded() {
        guard !isAnimating else { return }
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
        guard let w = window, w.isVisible, !isAnimating else { return }
        isAnimating = true
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
            w.orderOut(nil)
            w.alphaValue = 1
            self?.isAnimating = false
            self?.onMinimize?()
        })
    }

    public func restoreFromMenuBar() {
        guard let w = window else {
            makeWindow()
            updateSize(animate: false)
            window?.orderFrontRegardless()
            return
        }

        // If we have no saved frame, just show normally
        guard lastFrame.width > 16 else {
            updateSize(animate: false)
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

        updateSize(animate: false)
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

    private func updateSize(animate: Bool = true) {
        guard let host = hostingView, let w = window else { return }
        host.layoutSubtreeIfNeeded()
        let fitting = host.fittingSize
        let contentSize = stableContentSize(fitting: fitting)
        let frameSize = w.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size

        let currentFrame = w.frame
        var frame = currentFrame
        anchorX = currentFrame.minX   // respect user-dragged position
        frame.origin.x = currentFrame.minX
        frame.origin.y = currentFrame.maxY - frameSize.height
        frame.size = frameSize

        if animate, frame.size != currentFrame.size {
            animateFrameByHand(from: currentFrame, to: frame)
        } else {
            w.setFrame(frame, display: true, animate: false)
        }
    }

    private func stableContentSize(fitting: NSSize) -> NSSize {
        let maxStatusCount = max(state.workingCount, state.askCount, state.doneCount, state.apiErrCount)
        let expandedHeight = singleSessionExpandedHeight + CGFloat(max(maxStatusCount - 1, 0)) * sessionRowHeight
        return NSSize(
            width: max(fitting.width, maxBubbleWidth),
            height: max(fitting.height, compactBubbleHeight, expandedHeight)
        )
    }

    /// Manual frame-by-frame animation that locks the top-left corner at every step.
    /// AppKit's NSAnimationContext + setFrame(animate:true) interpolates origin.y
    /// and height as independent properties; their timing curves aren't lock-stepped,
    /// so the top edge drifts during expansion. This timer-based approach computes
    /// origin.y = fixedTop - currentHeight at each frame, guaranteeing zero drift.
    private func animateFrameByHand(from start: NSRect, to end: NSRect) {
        guard let w = window else { return }
        expandTimer?.invalidate()

        let topY = start.origin.y + start.height   // immutable anchor
        let anchorX = end.origin.x
        let startTime = CACurrentMediaTime()
        let duration: CFTimeInterval = 0.35

        let timer = Timer(fire: Date(), interval: 1.0 / 60.0, repeats: true) { [weak self, weak w] timer in
            guard let w = w else { timer.invalidate(); return }
            let elapsed = CACurrentMediaTime() - startTime
            let tRaw = min(elapsed / duration, 1.0)
            // easeInEaseOut cubic
            let t: CGFloat
            if tRaw < 0.5 {
                t = 4 * tRaw * tRaw * tRaw
            } else {
                t = 1 - pow(-2 * tRaw + 2, 3) / 2
            }

            let curW = start.width  + (end.width  - start.width)  * t
            let curH = start.height + (end.height - start.height) * t
            let curY = topY - curH

            var f = w.frame
            f.origin.x    = anchorX
            f.origin.y    = curY
            f.size.width  = curW
            f.size.height = curH
            w.setFrame(f, display: true, animate: false)

            if tRaw >= 1.0 {
                w.setFrame(end, display: true, animate: false)
                timer.invalidate()
                self?.expandTimer = nil
            }
        }
        expandTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func makeWindow() {
        let content = BubbleContent(state: state, onMinimize: { [weak self] in
            self?.minimizeToMenuBar()
        }, onStatusTap: { [weak self] kind in
            self?.onStatusTap?(kind)
        }, onSessionTap: { [weak self] session in
            self?.onSessionTap?(session)
        }, onHover: { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.window?.makeKey()
        }, onSizeChange: { [weak self] animate in
            self?.updateSize(animate: animate)
        }, activator: activator)
        let host = NSHostingView(rootView: content)

        let fitting = host.fittingSize
        let size = NSSize(width: max(fitting.width, 80), height: max(fitting.height, 60))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]

        // Wrap in AcceptsFirstMouseView so clicks work immediately
        let wrapper = AcceptsFirstMouseView(frame: NSRect(origin: .zero, size: size))
        wrapper.autoresizingMask = [.width, .height]
        wrapper.addSubview(host)

        // Use .titled (not .borderless) so NSVisualEffectView can blur
        // content behind the window. Hide all the chrome to keep it bubble-like.
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        if #available(macOS 11.0, *) {
            w.titlebarSeparatorStyle = .none
        }
        w.standardWindowButton(.closeButton)?.isHidden = true
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .floating
        w.isMovableByWindowBackground = true
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.ignoresMouseEvents = false
        w.acceptsMouseMovedEvents = true
        w.contentView = wrapper

        if let screen = NSScreen.main {
            let margin: CGFloat = 20
            // Reserve width for session-list expansion so the window
            // never grows past the right edge of the screen.
            let safeWidth = max(size.width, maxBubbleWidth)
            let safeFrameWidth = w.frameRect(
                forContentRect: NSRect(origin: .zero, size: NSSize(width: safeWidth, height: size.height))
            ).width
            let x = screen.visibleFrame.maxX - safeFrameWidth - margin
            let y = screen.visibleFrame.maxY - w.frame.height - margin
            anchorX = x
            w.setFrameOrigin(NSPoint(x: x, y: y))
        }

        hostingView = host
        window = w
    }
}
