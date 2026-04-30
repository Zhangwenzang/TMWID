import SwiftUI
import Tmwid
import AppKit

@main
struct TmwidApp: App {
    @StateObject private var state = AppState()
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("bubbleEnabled") private var bubbleEnabled = true
    @State private var watcher: StateFileWatcher?
    @State private var health: HealthChecker?
    @State private var bubble: BubbleWindowController?
    @State private var injector: SettingsInjector?
    @State private var codexInjector: CodeXInjector?
    @State private var sound: SoundPlayer?
    @State private var discovery: SessionDiscovery?
    @State private var activator: SessionActivator?

    private let paths = Paths()

    init() {
        // Prevent duplicate instances
        let dominated = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.tmwid.app"
        ).filter { $0 != NSRunningApplication.current }

        if let existing = dominated.first {
            existing.activate()
            // Exit immediately — another instance is already running
            Darwin.exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                state: state,
                onQuit: {
                    try? injector?.uninstall()
                    try? codexInjector?.uninstall()
                    NSApplication.shared.terminate(nil)
                },
                onBubbleToggle: { enabled in
                    if enabled {
                        bubble?.restoreFromMenuBar()
                    } else {
                        bubble?.minimizeToMenuBar()
                    }
                }
            )
        } label: {
            MenuBarLabel(state: state)
                .task { setupOnce() }
        }
        .menuBarExtraStyle(.menu)
        .onChange(of: state.sessions) { _ in
            sound?.playIfNeeded(
                currentSessions: state.sessions,
                enabled: soundEnabled
            )
            if bubbleEnabled {
                bubble?.showIfNeeded()
            }
        }
    }

    private func setupOnce() {
        let inj = SettingsInjector(paths: paths)
        try? inj.install()
        injector = inj

        let codexDir = "\(paths.home)/.codex"
        if FileManager.default.fileExists(atPath: codexDir) {
            let codexInj = CodeXInjector(paths: paths)
            try? codexInj.install()
            codexInjector = codexInj
        }

        let w = StateFileWatcher(directory: paths.stateDir)
        w.onChange = { sessions in
            Task { @MainActor in state.update(with: sessions) }
        }
        w.start()
        watcher = w

        let h = HealthChecker(directory: paths.stateDir)
        h.startPeriodic()
        health = h

        let act = SessionActivator()
        activator = act

        let b = BubbleWindowController(state: state)
        b.onMinimize = {
            bubbleEnabled = false
        }
        b.onStatusTap = { kind in
            if let session = state.sessions(for: kind).first {
                act.activate(session: session)
            }
        }
        b.activator = act
        b.onSessionTap = { session in
            act.activate(session: session)
        }
        bubble = b

        let s = SoundPlayer()
        s.playIfNeeded(currentSessions: state.sessions, enabled: false)
        sound = s

        let d = SessionDiscovery(
            stateDir: paths.stateDir,
            claudeProjectsDir: paths.claudeProjectsDir
        )
        d.onDiscovered = { [weak w] in
            // Re-scan state files so AppState picks up newly discovered sessions
            guard let w else { return }
            let sessions = w.scan()
            Task { @MainActor in state.update(with: sessions) }
        }
        d.scanOnce()
        d.startWatching()
        discovery = d
    }
}
