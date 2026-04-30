import Foundation
import AppKit

public final class SessionActivator {
    public init() {}

    public func activate(session: SessionState) {
        guard let app = findApp(for: session.pid) else { return }
        app.activate(options: .activateIgnoringOtherApps)
    }

    public func appIcon(for pid: Int32) -> NSImage? {
        guard let app = findApp(for: pid) else { return nil }
        return app.icon
    }

    private func findApp(for pid: Int32) -> NSRunningApplication? {
        var current = pid
        for _ in 0..<10 {
            if let app = NSRunningApplication(processIdentifier: current) {
                if app.activationPolicy == .regular { return app }
            }
            guard let ppid = parentPid(of: current) else { break }
            current = ppid
        }
        return nil
    }

    private func parentPid(of pid: Int32) -> Int32? {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &kinfo, &size, nil, 0) == 0 else { return nil }
        return kinfo.kp_eproc.e_ppid
    }
}
