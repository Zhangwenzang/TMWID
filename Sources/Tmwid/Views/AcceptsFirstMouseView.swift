import AppKit

final class AcceptsFirstMouseView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
